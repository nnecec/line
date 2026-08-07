//
//  DragSnapSession.swift
//  Line
//
//  Pure lifecycle state for one mouse-driven window drag.
//

import CoreGraphics

struct DragSnapSession {
    struct Configuration {
        let windowSnapping: Bool
        let restoreInitialWindowSize: Bool

        static let disabled = Configuration(
            windowSnapping: false,
            restoreInitialWindowSize: false
        )
    }

    enum Event {
        case dragged(currentFrame: CGRect?, configuration: Configuration)
        case windowResolved(initialFrame: CGRect)
        case windowResolutionFailed
        case released(currentFrame: CGRect?, hasSnapAction: Bool, windowSnapping: Bool)
    }

    enum Effect: Equatable {
        case resolveWindow
        case restoreInitialWindowSize
        case updateSnap
        case notifyWindowManipulated
        case eraseWindowRecords
        case closePreview
        case applySnap
        case clearRuntimeState
    }

    private enum State {
        case idle
        case resolvingWindow
        case ignoringDrag
        case tracking(initialFrame: CGRect)
    }

    private var state: State = .idle

    mutating func handle(_ event: Event) -> [Effect] {
        switch event {
        case let .dragged(currentFrame, configuration):
            return handleDragged(currentFrame: currentFrame, configuration: configuration)

        case let .windowResolved(initialFrame):
            guard case .resolvingWindow = state else {
                return []
            }
            state = .tracking(initialFrame: initialFrame)
            return []

        case .windowResolutionFailed:
            guard case .resolvingWindow = state else {
                return []
            }
            state = .ignoringDrag
            return []

        case let .released(currentFrame, hasSnapAction, windowSnapping):
            let shouldApplySnap: Bool
            if case let .tracking(initialFrame) = state,
               let currentFrame {
                shouldApplySnap = windowSnapping &&
                    hasSnapAction &&
                    DragSnapPolicy.hasWindowMoved(currentFrame, initialFrame)
            } else {
                shouldApplySnap = false
            }

            state = .idle
            return shouldApplySnap
                ? [.closePreview, .applySnap, .clearRuntimeState]
                : [.closePreview, .clearRuntimeState]
        }
    }

    private mutating func handleDragged(
        currentFrame: CGRect?,
        configuration: Configuration
    ) -> [Effect] {
        switch state {
        case .idle:
            state = .resolvingWindow
            return [.resolveWindow]

        case .resolvingWindow, .ignoringDrag:
            return []

        case let .tracking(initialFrame):
            guard let currentFrame,
                  DragSnapPolicy.hasWindowResized(currentFrame, initialFrame)
            else {
                return []
            }

            var effects: [Effect] = []
            if DragSnapPolicy.hasWindowMoved(currentFrame, initialFrame) {
                if configuration.restoreInitialWindowSize {
                    effects.append(.restoreInitialWindowSize)
                }
                if configuration.windowSnapping {
                    effects.append(.updateSnap)
                }
            }

            effects.append(.notifyWindowManipulated)
            effects.append(.eraseWindowRecords)
            return effects
        }
    }
}
