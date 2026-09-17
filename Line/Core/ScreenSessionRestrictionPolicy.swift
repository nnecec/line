//
//  ScreenSessionRestrictionPolicy.swift
//  Line
//
//  Pure lock/sleep/wake gate for window mutations.
//  ScreenSessionGate observes system notifications and executes the effects.
//

import Foundation
import os

/// Decides when Line must ignore HID-driven window actions around lock, sleep, and display wake.
///
/// Unlock and display wake commonly inject synthetic `flagsChanged` / mouse events. The default
/// Globe/Fn trigger is `maskSecondaryFn`, and top-edge drag snap is maximize — so those events
/// can resize the frontmost window to the screen's working bounds.
enum ScreenSessionRestrictionPolicy {
    static let postResumeDelay: Duration = .seconds(1)

    enum Event: Equatable {
        case locked
        case unlocked
        case willSleep
        case didWake
        case screensDidSleep
        case screensDidWake
        case resumeDelayElapsed(generation: UInt)
    }

    struct State: Equatable {
        var isRestricted: Bool
        var resumeGeneration: UInt

        static let unrestricted = State(isRestricted: false, resumeGeneration: 0)
    }

    enum Effect: Equatable {
        /// Drop in-flight sessions and drag snaps without applying them.
        case cancelPendingWindowActions
        /// Wait `postResumeDelay` then send `resumeDelayElapsed` with the current generation.
        case beginResumeDelay
    }

    static func reduce(state: inout State, event: Event) -> [Effect] {
        switch event {
        case .locked, .willSleep, .screensDidSleep:
            return restrictAndInvalidateResume(&state)

        case .unlocked, .didWake, .screensDidWake:
            var effects = restrictAndInvalidateResume(&state)
            effects.append(.beginResumeDelay)
            return effects

        case let .resumeDelayElapsed(generation):
            guard state.isRestricted, generation == state.resumeGeneration else {
                return []
            }
            state.isRestricted = false
            return []
        }
    }

    private static func restrictAndInvalidateResume(_ state: inout State) -> [Effect] {
        state.isRestricted = true
        state.resumeGeneration &+= 1
        return [.cancelPendingWindowActions]
    }
}

/// Process-wide restriction flag readable from event-tap callbacks.
enum ScreenSessionRestrictionFlag {
    private static let lock = OSAllocatedUnfairLock(initialState: false)

    static var isRestricted: Bool {
        lock.withLock { $0 }
    }

    static func publish(_ isRestricted: Bool) {
        lock.withLock { $0 = isRestricted }
    }
}
