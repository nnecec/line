//
//  AccessibilityManager.swift
//  Line
//
//  Created by nnecec on 2023-04-08.
//

import AppKit
import SwiftUI

/// Stores and manages the accessibility permission state for Line.
@MainActor
final class AccessibilityManager {
    static let shared: AccessibilityManager = .init()

    private var permissionCheckerTask: Task<(), Never>!
    private var activationRefreshObserver: NSObjectProtocol?

    private var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]
    private(set) var isGranted: Bool

    private init() {
        self.isGranted = Self.getStatus()

        // Setup permission change notification monitoring
        self.permissionCheckerTask = Task {
            let notifications = DistributedNotificationCenter
                .default()
                .notifications(named: .AXPermissionsChanged)

            for await _ in notifications {
                // It seems like the notification is sent immediately after a state change, sometimes before the actual
                // reading from `AXIsProcessTrustedWithOptions` is updated.
                // So sleep for 250 milliseconds (this is generous, but just to ensure that the reading will be correct).
                try? await Task.sleep(for: .milliseconds(250))

                let status = Self.getStatus()
                self.yield(status)
            }
        }

        self.activationRefreshObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                AccessibilityManager.shared.refreshStatus()
            }
        }
    }

    deinit {
        permissionCheckerTask.cancel()

        if let activationRefreshObserver {
            NotificationCenter.default.removeObserver(activationRefreshObserver)
        }

        let currentContinuations = Array(continuations.values)
        continuations.removeAll()

        for continuation in currentContinuations {
            continuation.finish()
        }
    }

    // MARK: Streaming

    /// Stream new changes to Line's accessibility permissions.
    /// - Parameter initial: whether to send an initial value corresponding to Line's current permissions
    /// - Returns: an AsyncStream.
    func stream(initial: Bool = true) -> AsyncStream<Bool> {
        AsyncStream<Bool> { continuation in
            let id = UUID()
            continuations[id] = continuation

            if initial {
                continuation.yield(isGranted)
            }

            continuation.onTermination = { [weak self] _ in
                guard let self else { return }

                Task { @MainActor in
                    self.continuations[id] = nil
                }
            }
        }
    }

    /// This will yield a new value to all streams if the provided value differs from the previous value.
    /// - Parameter value: the provided value.
    @MainActor
    private func yield(_ value: Bool) {
        guard value != isGranted else { return }

        let currentContinuations = continuations.values

        for continuation in currentContinuations {
            continuation.yield(value)
        }

        isGranted = value
    }

    // MARK: Permissions Checking

    /// Requests accessibility permissions to the user.
    /// - Returns: whether the user granted the permission.
    @discardableResult
    static func requestAccess() -> Bool {
        if shared.refreshStatus() {
            return true
        }

        let alert = NSAlert()
        alert.messageText = .init(
            localized: "Accessibility Request: Title",
            defaultValue: "\(Bundle.main.appName) Needs Accessibility Permissions"
        )
        alert.informativeText = String(
            localized: "Accessibility Request: Content",
            defaultValue: "Please grant access to be able to resize windows."
        )

        // Reference: https://x.com/leoshimo/status/1975642593569738755
        let button = alert.addButton(withTitle: .init(localized: "OK"))
        if #available(macOS 26.0, *) {
            button.tintProminence = .primary
        }

        alert.runModal()

        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        let status = AXIsProcessTrustedWithOptions(options)
        shared.yield(status)

        return status
    }

    /// Determines if the app has accessibility permissions.
    /// - Returns: whether the app has accessibility permissions.
    private static func getStatus() -> Bool {
        AXIsProcessTrusted()
    }

    /// Re-reads the current TCC state and publishes any change.
    /// - Returns: whether the app currently has accessibility permissions.
    @discardableResult
    func refreshStatus() -> Bool {
        let status = Self.getStatus()
        yield(status)
        return status
    }
}

private extension Notification.Name {
    /// Not publicly documented, but gets sent when ANY application's AX API permission change.
    /// From `HIServices.framework`
    static let AXPermissionsChanged = Notification.Name(rawValue: "com.apple.accessibility.api")
}
