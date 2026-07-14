//
//  WindowFrameResolver+WindowAction.swift
//  Line
//
//  Created via architecture refactor on 2026-07-02.
//

import AppKit
import CoreGraphics
import Foundation

extension WindowFrameResolver {
    /// Calculates the target frame using the Window Action request model.
    @MainActor
    static func calculateFrame(for request: WindowResizeRequest) -> FrameCalculationResult {
        let action = request.action

        // Check for no-op actions
        if case let .special(special) = action {
            if special == .noAction || special == .noSelection {
                return FrameCalculationResult(frame: CGRect(origin: request.bounds.centerPoint, size: .zero))
            }
        }

        // Check for focus actions (don't calculate frames)
        if case .focus = action {
            return FrameCalculationResult(frame: CGRect(origin: request.bounds.centerPoint, size: .zero))
        }

        // Delegate to the action's calculator
        let result = action.calculateFrame(for: request)

        // Validate result
        var validatedFrame = result.frame
        if validatedFrame.size.width < 0 || validatedFrame.size.height < 0 || !validatedFrame.isFinite {
            validatedFrame = CGRect(origin: request.bounds.centerPoint, size: .zero)
        }

        return FrameCalculationResult(frame: validatedFrame, sidesToAdjust: result.sidesToAdjust)
    }

    // MARK: - Convenience Methods

    /// Sync convenience for preview-style calculations.
    @MainActor
    static func calculateFrame(
        for action: WindowAction,
        bounds: CGRect,
        screen: NSScreen,
        padding: PaddingConfiguration? = nil
    ) -> CGRect {
        let request = WindowResizeRequest(
            window: nil,
            action: action,
            screen: screen,
            bounds: bounds,
            padding: padding ?? .zero
        )
        return calculateFrame(for: request).frame
    }

    /// Async convenience that resolves window properties and records.
    @MainActor
    static func calculateFrame(
        for action: WindowAction,
        window: Window,
        screen: NSScreen,
        bounds: CGRect,
        padding: PaddingConfiguration? = nil
    ) async -> CGRect {
        let request = await WindowResizeRequest.withRecords(
            window: window,
            action: action,
            screen: screen,
            bounds: bounds,
            padding: padding ?? .zero
        )
        return calculateFrame(for: request).frame
    }

    @MainActor
    static func calculateRevealedFrame(
        for action: WindowAction,
        window: Window,
        screen: NSScreen,
        padding: PaddingConfiguration? = nil
    ) async -> CGRect {
        await calculateFrame(
            for: action,
            window: window,
            screen: screen,
            bounds: screen.cgSafeScreenFrame,
            padding: padding
        )
    }

    @MainActor
    static func calculateStashedFrame(
        for action: WindowAction,
        window: Window,
        screen: NSScreen,
        peekSize: CGFloat,
        maxPeekPercent: CGFloat = 0.2
    ) async -> CGRect {
        let bounds = screen.cgSafeScreenFrame
        let revealedFrame = await calculateFrame(
            for: action,
            window: window,
            screen: screen,
            bounds: bounds
        )

        return calculateStashedFrame(
            for: action,
            revealedFrame: revealedFrame,
            bounds: bounds,
            peekSize: peekSize,
            maxPeekPercent: maxPeekPercent
        )
    }

    static func calculateStashedFrame(
        for action: WindowAction,
        revealedFrame: CGRect,
        bounds: CGRect,
        peekSize: CGFloat,
        maxPeekPercent: CGFloat = 0.2
    ) -> CGRect {
        var frame = revealedFrame
        let minPeekSize: CGFloat = 1

        guard let stashEdge = action.stashEdge else {
            return frame
        }

        switch stashEdge {
        case .left, .right:
            let maxPeekSize = frame.width * maxPeekPercent
            let clampedPeekSize = max(minPeekSize, min(peekSize, maxPeekSize))

            if stashEdge == .left {
                frame.origin.x = bounds.minX - frame.width + clampedPeekSize
            } else {
                frame.origin.x = bounds.maxX - clampedPeekSize
            }

        case .bottom:
            let maxPeekSize = frame.height * maxPeekPercent
            let clampedPeekSize = max(minPeekSize, min(peekSize, maxPeekSize))
            frame.origin.y = bounds.maxY - clampedPeekSize
        }

        return frame
    }
}

// MARK: - CGRect Helper Extension (避免与现有的冲突)

private extension CGRect {
    var centerPoint: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
