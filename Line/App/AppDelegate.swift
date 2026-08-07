//
//  AppDelegate.swift
//  Line
//
//  Created by nnecec on 2023-10-05.
//

import Darwin
import Defaults
import Scribe
import SwiftUI
import UserNotifications

enum InitialPresentationDecision: Equatable {
    case applyBackgroundPresentation
    case showPermissions

    static func resolve(launchedAsLoginItem: Bool, isAccessibilityGranted: Bool) -> Self {
        switch (launchedAsLoginItem, isAccessibilityGranted) {
        case (_, false):
            .showPermissions
        case (true, true), (false, true):
            .applyBackgroundPresentation
        }
    }
}

enum TerminateNotificationAcceptancePolicy {
    static func shouldAcceptTerminateNotification(
        senderPID: Int?,
        currentPID: Int,
        senderBundleIdentifier: String?,
        currentBundleIdentifier: String?
    ) -> Bool {
        guard let senderPID,
              senderPID != currentPID,
              let senderBundleIdentifier,
              let currentBundleIdentifier else {
            return false
        }

        return senderBundleIdentifier == currentBundleIdentifier
    }
}

enum AppLaunchCoordinationPolicy {
    static func shouldCoordinateDuplicateInstances(isRunningTests: Bool) -> Bool {
        !isRunningTests
    }
}

@Loggable
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let urlCommandHandler = URLCommandHandler()

    private static let terminateNotificationName = Notification.Name("com.nnecec.Line.terminate")
    private var terminateObserver: Any?

    private var launchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return
            event.eventID == kAEOpenApplication &&
            event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            NSClassFromString("XCTestCase") != nil
    }

    @MainActor
    func applicationDidFinishLaunching(_: Notification) {
        configureLogging()
        SparkleUpdater.shared.start()

        let shouldCoordinateDuplicateInstances = AppLaunchCoordinationPolicy
            .shouldCoordinateDuplicateInstances(isRunningTests: isRunningTests)

        if shouldCoordinateDuplicateInstances {
            // Register before broadcasting so other instances can receive the signal
            registerTerminateObserver()
        }

        // The Window Action path is the only active calculation path.

        // Restore the default bindings if no saved keybinds are available.
        if Defaults[.keybinds].isEmpty {
            log.warn("Keybinds not initialized, setting defaults")
            Defaults[.keybinds] = BoundWindowAction.defaultKeybinds
        }

        Task { @MainActor in
            configureInitialPresentation()
        }

        DataPatcher.run()
        LaunchAtLoginManager.shared.start()

        UNUserNotificationCenter.current().delegate = self
        AppDelegate.requestNotificationAuthorization()

        // Register for URL handling
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        let stalePIDs = shouldCoordinateDuplicateInstances ? broadcastTerminateToOtherInstances() : []

        // Wait for other instances to fully exit before installing event taps to prevent conflicts
        Task { @MainActor in
            await waitForInstancesToExit(pids: stalePIDs, timeout: .seconds(3))
            LineCoordinator.shared.start()
            WindowDragManager.shared.addObservers()
            StashManager.shared.start()
        }
    }

    /// Subscribes to the terminate notification so this instance shuts down when a newer Line instance launches.
    private func registerTerminateObserver() {
        terminateObserver = DistributedNotificationCenter.default().addObserver(
            forName: Self.terminateNotificationName,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }

            let senderPID = notification.userInfo?["pid"] as? Int
            let senderBundleIdentifier = senderPID
                .flatMap { NSRunningApplication(processIdentifier: pid_t($0))?.bundleIdentifier }

            guard TerminateNotificationAcceptancePolicy.shouldAcceptTerminateNotification(
                senderPID: senderPID,
                currentPID: Int(ProcessInfo.processInfo.processIdentifier),
                senderBundleIdentifier: senderBundleIdentifier,
                currentBundleIdentifier: Bundle.main.bundleIdentifier
            ) else {
                log.warn("Rejected unauthenticated terminate broadcast")
                return
            }

            log.info("Received terminate broadcast from newer Line instance, shutting down")
            NSApp.terminate(nil)
        }
    }

    /// Sends the terminate notification to any other running Line instances, and returns their PIDs.
    @discardableResult
    private func broadcastTerminateToOtherInstances() -> [pid_t] {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let bundleId = Bundle.main.bundleIdentifier ?? "com.nnecec.Line"

        let otherInstances = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == bundleId && $0.processIdentifier != currentPID
        }

        guard !otherInstances.isEmpty else {
            log.info("No other Line instances found")
            return []
        }

        log.info("Found \(otherInstances.count) other Line instance(s), broadcasting terminate notification")

        DistributedNotificationCenter.default().post(
            name: Self.terminateNotificationName,
            object: nil,
            userInfo: ["pid": Int(currentPID)]
        )

        return otherInstances.map(\.processIdentifier)
    }

    /// Waits until all provided PIDs have exited, or until the timeout is reached.
    private func waitForInstancesToExit(pids: [pid_t], timeout: Duration) async {
        guard !pids.isEmpty else { return }

        let deadline = ContinuousClock.now + timeout

        while ContinuousClock.now < deadline {
            let allGone = pids.allSatisfy { NSRunningApplication(processIdentifier: $0) == nil }
            if allGone {
                log.info("All prior Line instances have exited")
                return
            }
            try? await Task.sleep(for: .milliseconds(100))
        }

        let surviving = pids.filter { NSRunningApplication(processIdentifier: $0) != nil }
        if !surviving.isEmpty {
            log.warn("Timed out waiting for prior Line instances to exit, force killing \(surviving.count) instance(s)")
            for pid in surviving {
                kill(pid, SIGKILL)
            }
        }
    }

    /// Applies baseline logging configuration for Scribe.
    private func configureLogging() {
        LogManager.shared.configuration.includeFileAndLineNumber = false
        LogManager.shared.minimumLevel = ApplicationLoggingPolicy.minimumLevel(for: .current)
    }

    @MainActor
    private func configureInitialPresentation() {
        ApplicationPresentationController.shared.ensureReachablePresentation()

        let decision = InitialPresentationDecision.resolve(
            launchedAsLoginItem: launchedAsLoginItem,
            isAccessibilityGranted: AccessibilityManager.shared.isGranted
        )

        switch decision {
        case .applyBackgroundPresentation:
            ApplicationPresentationController.shared.applyPreferredBackgroundPresentation()
        case .showPermissions:
            SettingsWindowHost.shared.show(tab: .permissions)
        }
    }

    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent _: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {
            log.info("Failed to get URL from event")
            return
        }

        log.info("Received URL: \(ApplicationLogPrivacy.urlDescription(url))")
        urlCommandHandler.handle(url)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        SettingsWindowHost.shared.settingsWindowDidClose()
        return false
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        SettingsWindowHost.shared.show()
        return true
    }

    func applicationDockMenu(_: NSApplication) -> NSMenu? {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: String(localized: "Settings…", comment: "Dock menu item that opens Line settings"),
            action: #selector(openSettingsFromDock(_:)),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let permissionsItem = NSMenuItem(
            title: String(
                localized: "Permissions…",
                comment: "Dock menu item that opens the Permissions settings tab"
            ),
            action: #selector(openPermissionsFromDock(_:)),
            keyEquivalent: ""
        )
        permissionsItem.target = self
        menu.addItem(permissionsItem)

        menu.addItem(.separator())

        let checkUpdatesItem = NSMenuItem(
            title: String(
                localized: "Check for Updates…",
                comment: "Dock menu item that checks for updates"
            ),
            action: #selector(checkForUpdatesFromDock(_:)),
            keyEquivalent: ""
        )
        checkUpdatesItem.target = self
        checkUpdatesItem.isEnabled = SparkleUpdater.shared.canCheckForUpdates
        menu.addItem(checkUpdatesItem)

        return menu
    }

    @MainActor @objc private func openSettingsFromDock(_: Any?) {
        SettingsWindowHost.shared.show()
    }

    @MainActor @objc private func openPermissionsFromDock(_: Any?) {
        SettingsWindowHost.shared.show(tab: .permissions)
    }

    @MainActor @objc private func checkForUpdatesFromDock(_: Any?) {
        SparkleUpdater.shared.checkForUpdates()
    }

    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        // LineCoordinator and WindowDragManager are explicitly shut down so that their
        // event monitors are stopped immediately (in case they are active)
        LineCoordinator.shared.shutdown()
        WindowDragManager.shared.shutdown()
        StashManager.shared.shutdown()
        return .terminateNow
    }

    func application(_: NSApplication, open urls: [URL]) {
        for url in urls {
            urlCommandHandler.handle(url)
        }
    }
}
