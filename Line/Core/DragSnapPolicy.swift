//
//  DragSnapPolicy.swift
//  Line
//
//  Pure geometry and decision rules for window drag snapping.
//  WindowDragManager executes previews and applies; this module decides direction.
//

import CoreGraphics
import Foundation

enum DragSnapPolicy {
    enum Outcome: Equatable {
        /// Snap preview/action should become this direction.
        case updateDirection(WindowDirection)
        /// Mouse returned to the safe zone — clear any active snap direction.
        case clear
        /// No change to the current snap direction.
        case unchanged
    }

    /// Inset from the top edge of the flipped screen frame.
    /// Uses half the menu bar height (minimum the edge inset) so top snap
    /// doesn't fight Mission Control / menu bar drag.
    static func topInset(menubarHeight: CGFloat, edgeInset: CGFloat) -> CGFloat {
        max(menubarHeight / 2, edgeInset)
    }

    /// Screen frame region where the cursor does *not* trigger a snap.
    /// `screenFrame` must already be in the same coordinate space as `mouseLocation`
    /// (WindowDragManager uses flipped Y relative to the main screen).
    static func ignoredFrame(
        screenFrame: CGRect,
        edgeInset: CGFloat,
        topInset: CGFloat
    ) -> CGRect {
        var frame = screenFrame
        frame.origin.x += edgeInset
        frame.size.width -= edgeInset * 2
        frame.origin.y += topInset
        frame.size.height -= edgeInset + topInset
        return frame
    }

    /// Decide whether the current drag should update, clear, or keep the snap direction.
    static func decide(
        mouseLocation: CGPoint,
        screenFrame: CGRect,
        ignoredFrame: CGRect,
        currentDirection: WindowDirection
    ) -> Outcome {
        if !ignoredFrame.contains(mouseLocation) {
            let newDirection = WindowDirection.getSnapDirection(
                mouseLocation: mouseLocation,
                currentDirection: currentDirection,
                screenFrame: screenFrame,
                ignoredFrame: ignoredFrame
            )
            return newDirection != currentDirection
                ? .updateDirection(newDirection)
                : .unchanged
        }

        if !currentDirection.isNoOp {
            return .clear
        }

        return .unchanged
    }

    /// True when no corner of the window matches the initial frame (translated).
    static func hasWindowMoved(_ windowFrame: CGRect, _ initialFrame: CGRect) -> Bool {
        !initialFrame.topLeftPoint.approximatelyEqual(to: windowFrame.topLeftPoint) &&
            !initialFrame.topRightPoint.approximatelyEqual(to: windowFrame.topRightPoint) &&
            !initialFrame.bottomLeftPoint.approximatelyEqual(to: windowFrame.bottomLeftPoint) &&
            !initialFrame.bottomRightPoint.approximatelyEqual(to: windowFrame.bottomRightPoint)
    }

    /// True when any corner differs (moved or resized).
    static func hasWindowResized(_ windowFrame: CGRect, _ initialFrame: CGRect) -> Bool {
        !initialFrame.topLeftPoint.approximatelyEqual(to: windowFrame.topLeftPoint) ||
            !initialFrame.topRightPoint.approximatelyEqual(to: windowFrame.topRightPoint) ||
            !initialFrame.bottomLeftPoint.approximatelyEqual(to: windowFrame.bottomLeftPoint) ||
            !initialFrame.bottomRightPoint.approximatelyEqual(to: windowFrame.bottomRightPoint)
    }
}
