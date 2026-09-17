//
//  ScreenSessionGate.swift
//  Line
//
//  Observes lock/sleep/wake and applies ScreenSessionRestrictionPolicy.
//

import AppKit
import CoreGraphics
import Scribe

/// Runtime counterpart to `ScreenSessionRestrictionPolicy`.
///
/// While restricted, HID-driven window actions must be cancelled or ignored so synthetic events
/// after unlock cannot apply a layout (commonly maximize / full working bounds).
@Loggable
@MainActor
final class ScreenSessionGate {
    static let shared = ScreenSessionGate()

    private var state = ScreenSessionRestrictionPolicy.State.unrestricted
    private var observers: [NSObjectProtocol] = []
    private var resumeTask: Task<(), Never>?
    private var onCancelPendingWindowActions: (() -> ())?

    var isRestricted: Bool {
        ScreenSessionRestrictionFlag.isRestricted
    }

    private init() {}

    func start(onCancelPendingWindowActions: @escaping () -> ()) {
        shutdown()
        self.onCancelPendingWindowActions = onCancelPendingWindowActions

        if isScreenCurrentlyLocked() {
            apply(.locked)
        }

        observe(
            DistributedNotificationCenter.default(),
            name: Notification.Name("com.apple.screenIsLocked"),
            event: .locked
        )
        observe(
            DistributedNotificationCenter.default(),
            name: Notification.Name("com.apple.screenIsUnlocked"),
            event: .unlocked
        )
        observe(NSWorkspace.shared.notificationCenter, name: NSWorkspace.willSleepNotification, event: .willSleep)
        observe(NSWorkspace.shared.notificationCenter, name: NSWorkspace.didWakeNotification, event: .didWake)
        observe(
            NSWorkspace.shared.notificationCenter,
            name: NSWorkspace.screensDidSleepNotification,
            event: .screensDidSleep
        )
        observe(
            NSWorkspace.shared.notificationCenter,
            name: NSWorkspace.screensDidWakeNotification,
            event: .screensDidWake
        )
    }

    func shutdown() {
        resumeTask?.cancel()
        resumeTask = nil
        onCancelPendingWindowActions = nil

        for observer in observers {
            DistributedNotificationCenter.default().removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()

        state = .unrestricted
        ScreenSessionRestrictionFlag.publish(false)
    }

    private func observe(
        _ center: NotificationCenter,
        name: Notification.Name,
        event: ScreenSessionRestrictionPolicy.Event
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.apply(event)
            }
        }
        observers.append(token)
    }

    private func apply(_ event: ScreenSessionRestrictionPolicy.Event) {
        let effects = ScreenSessionRestrictionPolicy.reduce(state: &state, event: event)
        ScreenSessionRestrictionFlag.publish(state.isRestricted)

        for effect in effects {
            switch effect {
            case .cancelPendingWindowActions:
                log.info("Restricting window actions around lock or wake")
                onCancelPendingWindowActions?()

            case .beginResumeDelay:
                let generation = state.resumeGeneration
                resumeTask?.cancel()
                resumeTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: ScreenSessionRestrictionPolicy.postResumeDelay)
                    guard !Task.isCancelled else { return }
                    self?.apply(.resumeDelayElapsed(generation: generation))
                }
            }
        }

        if !state.isRestricted {
            log.info("Window action restriction lifted")
            resumeTask = nil
        }
    }

    /// Reads the current lock bit from the Quartz session dictionary.
    /// Missing keys degrade to unlocked; this is only used to seed state at launch.
    private func isScreenCurrentlyLocked() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as NSDictionary? else {
            return false
        }
        return (session["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }
}
