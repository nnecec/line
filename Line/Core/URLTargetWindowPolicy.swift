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
    static func resolve(
        candidates: [Window],
        userDefined: Window?,
        stickyWindow: Window?,
        stickyTime: Date?,
        now: Date = Date(),
        stickyTTL: TimeInterval = stickyTTL,
        lineBundleID: String? = Bundle.main.bundleIdentifier
    ) -> Window? {
        if let userDefined {
            return userDefined
        }

        if let stickyWindow,
           let stickyTime,
           now.timeIntervalSince(stickyTime) <= stickyTTL,
           isEligibleSticky(stickyWindow, lineBundleID: lineBundleID) {
            return stickyWindow
        }

        return candidates.first
    }

    /// Filter used by direction / action / keybind verbs for visible regular app windows.
    static func isEligibleCandidate(_ window: Window, lineBundleID: String?) -> Bool {
        guard let app = window.nsRunningApplication else { return false }
        let isLine = app.bundleIdentifier == lineBundleID
        let isRegular = app.activationPolicy == .regular
        let isVisible = !window.isApplicationHidden && !window.minimized
        return !isLine && isRegular && isVisible
    }

    private static func isEligibleSticky(_ window: Window, lineBundleID: String?) -> Bool {
        guard let app = window.nsRunningApplication else { return false }
        return app.bundleIdentifier != lineBundleID
            && !window.isApplicationHidden
            && !window.minimized
    }
}
