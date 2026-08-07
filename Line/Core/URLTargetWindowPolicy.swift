//
//  URLTargetWindowPolicy.swift
//  Line
//
//  Unified target-window selection for URL automation verbs.
//

import Foundation

enum URLTargetWindowPolicy {
    static let stickyTTL: TimeInterval = 5

    /// Choose a target from candidate windows.
    /// Priority: user-defined target → sticky last-active (within TTL, still eligible) → first candidate.
    static func resolve<Target>(
        candidates: [Target],
        userDefined: Target?,
        stickyWindow: Target?,
        stickyTime: Date?,
        now: Date = Date(),
        stickyTTL: TimeInterval = stickyTTL,
        isEligible: (Target) -> Bool
    ) -> Target? {
        if let userDefined, isEligible(userDefined) {
            return userDefined
        }

        if let stickyWindow,
           let stickyTime,
           (0...stickyTTL).contains(now.timeIntervalSince(stickyTime)),
           isEligible(stickyWindow) {
            return stickyWindow
        }

        return candidates.first(where: isEligible)
    }

    /// Filter used by direction / action / keybind verbs for visible regular app windows.
    static func isEligibleCandidate(_ window: Window, lineBundleID: String?) -> Bool {
        guard let app = window.nsRunningApplication else { return false }
        let isLine = app.bundleIdentifier == lineBundleID
        let isRegular = app.activationPolicy == .regular
        let isVisible = !window.isApplicationHidden && !window.minimized
        return !isLine && isRegular && isVisible
    }
}
