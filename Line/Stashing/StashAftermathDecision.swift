//
//  StashAftermathDecision.swift
//  Line
//
//  Pure post-resize decision for stashed windows.
//  StashManager executes the outcome (AX, store, throttle).
//

import CoreGraphics
import Foundation

/// Decision table for what StashManager should do after a window action is applied.
enum StashAftermathDecision {
    /// Inputs available without performing AX side effects.
    struct Input: Equatable {
        /// Action that was just applied to the window.
        var action: WindowAction
        /// Whether this window is currently managed as stashed.
        var isManaged: Bool
        /// Whether a stash edge action should be redirected to another screen
        /// (edge-eligible screen differs from the action's current screen).
        var preferredScreenDiffersFromCurrent: Bool
        /// Whether the live window frame is fully inside the current screen's safe frame.
        /// Used when refreshing managed frames after grow/shrink-style actions.
        var isWindowFullyOnScreen: Bool
        /// Last recorded action for undo reprocessing (nil when unknown).
        var lastActionForUndo: WindowAction?
    }

    enum Outcome: Equatable {
        /// Create stash bookkeeping and hide to the edge (on the current screen).
        case stash
        /// Re-enter decision/execution on the edge-eligible screen.
        case redirectStashToPreferredScreen
        /// Stop managing; optionally reset frame to restore geometry.
        case unstash(resetFrame: Bool)
        /// Re-run aftermath with this action (undo resolves to prior action).
        case reprocess(WindowAction)
        /// Managed window grew/shrank: recompute stash frames; may mark revealed.
        case refreshManagedFrames(markRevealedIfFullyOnScreen: Bool)
        /// No store/AX change.
        case ignore
        /// Drop from stash management without restoring a frame.
        case unmanage
    }

    static func decide(_ input: Input) -> Outcome {
        if input.action.stashEdge != nil {
            if input.preferredScreenDiffersFromCurrent {
                return .redirectStashToPreferredScreen
            }
            return .stash
        }

        if case let .special(special) = input.action, special == .initialFrame {
            return .unstash(resetFrame: false)
        }

        if case .special(.undo) = input.action {
            guard let last = input.lastActionForUndo else {
                return .ignore
            }
            if case let .special(sp) = last, sp == .undo {
                return .ignore
            }
            return .reprocess(last)
        }

        if case let .incremental(incr) = input.action {
            if isSizeAdjustingIncremental(incr) {
                guard input.isManaged else {
                    return .ignore
                }
                return .refreshManagedFrames(markRevealedIfFullyOnScreen: input.isWindowFullyOnScreen)
            }
            // Move-style incremental: leave managed state alone for now.
            return .ignore
        }

        // Any other successful resize displaces stash placement.
        return .unmanage
    }

    /// Grow / shrink / scale actions that may leave a hidden stashed window on-screen.
    static func isSizeAdjustingIncremental(_ action: WindowAction.IncrementalAction) -> Bool {
        switch action {
        case .growTop, .growBottom, .growLeft, .growRight, .growHorizontal, .growVertical,
             .shrinkTop, .shrinkBottom, .shrinkLeft, .shrinkRight, .shrinkHorizontal, .shrinkVertical,
             .larger, .smaller, .scaleUp, .scaleDown:
            true
        case .moveUp, .moveDown, .moveLeft, .moveRight:
            false
        }
    }
}
