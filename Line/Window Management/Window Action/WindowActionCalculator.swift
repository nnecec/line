//
//  WindowActionCalculator.swift
//  Line
//
//  Created via architecture refactor on 2026-07-02.
//
//  Protocol for calculating window frames from actions.
//  Each WindowAction variant implements this protocol, encapsulating its own calculation logic.
//

import AppKit
import CoreGraphics
import Defaults
import Foundation
import SwiftUI

/// Protocol for calculating target frames from window actions.
protocol WindowActionCalculator {
    /// Calculates the target frame for this action.
    /// - Parameter request: Immutable request containing all necessary context.
    /// - Returns: The calculated frame (raw, without padding applied).
    @MainActor
    func calculateFrame(for request: WindowResizeRequest) -> CGRect
}

/// Result of a frame calculation, including optional side adjustment data.
struct FrameCalculationResult {
    let frame: CGRect
    let sidesToAdjust: Edge.Set?

    init(frame: CGRect, sidesToAdjust: Edge.Set? = nil) {
        self.frame = frame
        self.sidesToAdjust = sidesToAdjust
    }
}

// MARK: - WindowAction Calculator Dispatch

extension WindowAction {
    /// Calculates the target frame for this action.
    /// Dispatches to the appropriate calculator based on the action type.
    @MainActor
    func calculateFrame(for request: WindowResizeRequest) -> FrameCalculationResult {
        switch self {
        case let .standard(standard):
            FrameCalculationResult(frame: standard.calculateFrame(for: request))

        case let .incremental(incremental):
            incremental.calculateFrameWithSides(for: request)

        case .focus:
            // Focus actions don't calculate frames
            FrameCalculationResult(frame: .zero)

        case .screen:
            // Screen switch actions don't calculate frames (handled by LineCoordinator)
            FrameCalculationResult(frame: .zero)

        case let .custom(custom):
            FrameCalculationResult(frame: custom.calculateFrame(for: request))

        case .cycle:
            // Cycle actions don't calculate frames directly (handled by LineCoordinator)
            FrameCalculationResult(frame: .zero)

        case .stash:
            FrameCalculationResult(frame: WindowAction.StandardWindowAction.center(.geometric).calculateFrame(for: request))

        case let .special(special):
            special.calculateFrameWithRequest(for: request)
        }
    }
}

// MARK: - StandardWindowAction Calculator

extension WindowAction.StandardWindowAction: WindowActionCalculator {
    func calculateFrame(for request: WindowResizeRequest) -> CGRect {
        let bounds = request.paddedBounds

        switch self {
        case let .proportional(layout):
            return layout.calculateFrame(in: bounds)

        case .maximize:
            return bounds

        case .almostMaximize:
            return bounds.insetBy(dx: 20, dy: 20)

        case .fullscreen:
            return bounds

        case .maximizeHeight:
            guard let properties = request.windowProperties else {
                return bounds
            }
            return CGRect(
                x: properties.frame.minX,
                y: bounds.minY,
                width: properties.frame.width,
                height: bounds.height
            )

        case .maximizeWidth:
            guard let properties = request.windowProperties else {
                return bounds
            }
            return CGRect(
                x: bounds.minX,
                y: properties.frame.minY,
                width: bounds.width,
                height: properties.frame.height
            )

        case .fillAvailableSpace:
            return calculateFillAvailableSpace(for: request)

        case let .center(mode):
            guard let properties = request.windowProperties else {
                return bounds
            }

            let windowSize = properties.frame.size
            let centeredX = bounds.minX + (bounds.width - windowSize.width) / 2
            let centeredY = bounds.minY + (bounds.height - windowSize.height) / 2

            switch mode {
            case .geometric:
                return CGRect(origin: CGPoint(x: centeredX, y: centeredY), size: windowSize)

            case .macOS:
                // macOS-style center has a Y offset
                let yOffset = getMacOSCenterYOffset(screenHeight: request.screen.frame.height)
                return CGRect(
                    origin: CGPoint(x: centeredX, y: centeredY - yOffset),
                    size: windowSize
                )
            }
        }
    }

    /// Calculates the Y offset for macOS-style centering.
    private func getMacOSCenterYOffset(screenHeight: CGFloat) -> CGFloat {
        WindowFrameUtility.macOSCenterYOffset(for: screenHeight)
    }

    private func calculateFillAvailableSpace(for request: WindowResizeRequest) -> CGRect {
        guard let properties = request.windowProperties else {
            return request.paddedBounds
        }

        let currentFrame = properties.frame
        let bounds = request.paddedBounds
        // Prefer lightweight CG list: fill-available only needs frames, not full AX Window objects.
        // CG bounds and AX frames share the same coordinate space (see Window.fromWindowInfo matching).
        let visibleWindowFrames = request.visibleWindowFrames
            ?? WindowUtility.lightweightWindowList().map(\.frame)

        let obstacleFrames = visibleWindowFrames.compactMap { frame -> CGRect? in
            guard !frame.intersects(currentFrame) else {
                return nil
            }

            let clippedFrame = frame.intersection(bounds)
            return clippedFrame.isNull || clippedFrame.isEmpty ? nil : clippedFrame
        }

        var minX = bounds.minX
        var minY = bounds.minY
        var maxX = bounds.maxX
        var maxY = bounds.maxY

        for frame in obstacleFrames {
            if frame.maxX <= currentFrame.minX {
                minX = max(minX, frame.maxX)
            }
            if frame.maxY <= currentFrame.minY {
                minY = max(minY, frame.maxY)
            }
            if frame.minX >= currentFrame.maxX {
                maxX = min(maxX, frame.minX)
            }
            if frame.minY >= currentFrame.maxY {
                maxY = min(maxY, frame.minY)
            }
        }

        struct Boundary: Hashable {
            let min: CGFloat
            let max: CGFloat
        }

        let xBoundaries: Set<Boundary> = [
            Boundary(min: minX, max: maxX),
            Boundary(min: currentFrame.minX, max: maxX),
            Boundary(min: minX, max: currentFrame.maxX),
            Boundary(min: currentFrame.minX, max: bounds.maxX),
            Boundary(min: bounds.minX, max: currentFrame.maxX),
            Boundary(min: bounds.minX, max: bounds.maxX)
        ]

        let yBoundaries: Set<Boundary> = [
            Boundary(min: minY, max: maxY),
            Boundary(min: currentFrame.minY, max: maxY),
            Boundary(min: minY, max: currentFrame.maxY),
            Boundary(min: currentFrame.minY, max: bounds.maxY),
            Boundary(min: bounds.minY, max: currentFrame.maxY),
            Boundary(min: bounds.minY, max: bounds.maxY)
        ]

        let candidates = xBoundaries.flatMap { xBoundary in
            yBoundaries.compactMap { yBoundary -> CGRect? in
                let frame = CGRect(
                    x: xBoundary.min,
                    y: yBoundary.min,
                    width: xBoundary.max - xBoundary.min,
                    height: yBoundary.max - yBoundary.min
                )

                guard frame.width >= 0, frame.height >= 0 else {
                    return nil
                }

                return obstacleFrames.allSatisfy { !$0.intersects(frame) } ? frame : nil
            }
        }

        return candidates.max { $0.size.area < $1.size.area } ?? currentFrame
    }
}

// MARK: - IncrementalAction Calculator

extension WindowAction.IncrementalAction {
    @MainActor
    func calculateFrameWithSides(for request: WindowResizeRequest) -> FrameCalculationResult {
        guard let properties = request.windowProperties else {
            return FrameCalculationResult(frame: .zero)
        }

        // Can't resize a non-resizable window
        if !properties.isResizable, isSizeAdjustment {
            return FrameCalculationResult(frame: properties.frame)
        }

        let currentFrame = properties.frame
        let bounds = request.paddedBounds

        switch self {
        // Move actions
        case .moveUp:
            let newFrame = currentFrame.offsetBy(dx: 0, dy: -getIncrementValue(bounds))
            return FrameCalculationResult(frame: newFrame)

        case .moveDown:
            let newFrame = currentFrame.offsetBy(dx: 0, dy: getIncrementValue(bounds))
            return FrameCalculationResult(frame: newFrame)

        case .moveLeft:
            let newFrame = currentFrame.offsetBy(dx: -getIncrementValue(bounds), dy: 0)
            return FrameCalculationResult(frame: newFrame)

        case .moveRight:
            let newFrame = currentFrame.offsetBy(dx: getIncrementValue(bounds), dy: 0)
            return FrameCalculationResult(frame: newFrame)

        // Size adjustment actions
        case .larger, .smaller, .scaleUp, .scaleDown:
            let increment = getIncrementValue(bounds)
            let isGrowing = self == .larger || self == .scaleUp
            let isProportional = self == .scaleUp || self == .scaleDown

            // Determine which edges to adjust based on edges touching bounds
            let edgesTouchingBounds = currentFrame.getEdgesTouchingBounds(bounds)
            let sidesToAdjust = Edge.Set.all.subtracting(edgesTouchingBounds)

            let newFrame = adjustSize(
                of: currentFrame,
                by: isGrowing ? increment : -increment,
                sides: sidesToAdjust,
                proportional: isProportional,
                bounds: bounds
            )
            return FrameCalculationResult(frame: newFrame, sidesToAdjust: sidesToAdjust)

        // Grow/Shrink actions
        case .growTop, .shrinkTop:
            let sidesToAdjust = Edge.Set.top
            let increment = getIncrementValue(bounds) * (self == .growTop ? 1 : -1)
            let newFrame = adjustSize(of: currentFrame, by: increment, sides: sidesToAdjust, bounds: bounds)
            return FrameCalculationResult(frame: newFrame, sidesToAdjust: sidesToAdjust)

        case .growBottom, .shrinkBottom:
            let sidesToAdjust = Edge.Set.bottom
            let increment = getIncrementValue(bounds) * (self == .growBottom ? 1 : -1)
            let newFrame = adjustSize(of: currentFrame, by: increment, sides: sidesToAdjust, bounds: bounds)
            return FrameCalculationResult(frame: newFrame, sidesToAdjust: sidesToAdjust)

        case .growLeft, .shrinkLeft:
            let sidesToAdjust = Edge.Set.leading
            let increment = getIncrementValue(bounds) * (self == .growLeft ? 1 : -1)
            let newFrame = adjustSize(of: currentFrame, by: increment, sides: sidesToAdjust, bounds: bounds)
            return FrameCalculationResult(frame: newFrame, sidesToAdjust: sidesToAdjust)

        case .growRight, .shrinkRight:
            let sidesToAdjust = Edge.Set.trailing
            let increment = getIncrementValue(bounds) * (self == .growRight ? 1 : -1)
            let newFrame = adjustSize(of: currentFrame, by: increment, sides: sidesToAdjust, bounds: bounds)
            return FrameCalculationResult(frame: newFrame, sidesToAdjust: sidesToAdjust)

        case .growHorizontal, .shrinkHorizontal:
            let sidesToAdjust: Edge.Set = [.leading, .trailing]
            let increment = getIncrementValue(bounds) * (self == .growHorizontal ? 1 : -1)
            let newFrame = adjustSize(of: currentFrame, by: increment, sides: sidesToAdjust, bounds: bounds)
            return FrameCalculationResult(frame: newFrame, sidesToAdjust: sidesToAdjust)

        case .growVertical, .shrinkVertical:
            let sidesToAdjust: Edge.Set = [.top, .bottom]
            let increment = getIncrementValue(bounds) * (self == .growVertical ? 1 : -1)
            let newFrame = adjustSize(of: currentFrame, by: increment, sides: sidesToAdjust, bounds: bounds)
            return FrameCalculationResult(frame: newFrame, sidesToAdjust: sidesToAdjust)
        }
    }

    private var isSizeAdjustment: Bool {
        switch self {
        case .larger, .smaller, .scaleUp, .scaleDown,
             .growTop, .growBottom, .growLeft, .growRight, .growHorizontal, .growVertical,
             .shrinkTop, .shrinkBottom, .shrinkLeft, .shrinkRight, .shrinkHorizontal, .shrinkVertical:
            true
        case .moveUp, .moveDown, .moveLeft, .moveRight:
            false
        }
    }

    private func getIncrementValue(_: CGRect) -> CGFloat {
        let configured = Defaults[.sizeIncrement]
        return configured > 0 ? configured : 30
    }

    private func adjustSize(
        of frame: CGRect,
        by increment: CGFloat,
        sides: Edge.Set,
        proportional: Bool = false,
        bounds: CGRect
    ) -> CGRect {
        var newFrame = frame

        if proportional {
            // Proportional scaling
            let aspectRatio = frame.width / frame.height
            let widthIncrement = sides.contains(.leading) || sides.contains(.trailing) ? increment : 0
            let heightIncrement = sides.contains(.top) || sides.contains(.bottom) ? increment : 0

            if widthIncrement != 0, heightIncrement != 0 {
                // Both dimensions: maintain aspect ratio
                newFrame.size.width += widthIncrement
                newFrame.size.height = newFrame.width / aspectRatio
            } else if widthIncrement != 0 {
                newFrame.size.width += widthIncrement
                newFrame.size.height = newFrame.width / aspectRatio
            } else if heightIncrement != 0 {
                newFrame.size.height += heightIncrement
                newFrame.size.width = newFrame.height * aspectRatio
            }
        } else {
            // Independent dimension adjustment
            if sides.contains(.leading) || sides.contains(.trailing) {
                newFrame.size.width += increment
            }
            if sides.contains(.top) || sides.contains(.bottom) {
                newFrame.size.height += increment
            }
        }

        // Adjust origin based on which sides are being modified
        if sides.contains(.leading) {
            newFrame.origin.x -= increment / 2
        }
        if sides.contains(.top) {
            newFrame.origin.y -= increment / 2
        }

        // Clamp to bounds
        newFrame = WindowFrameUtility.clamp(newFrame, to: bounds)

        return newFrame
    }
}

// MARK: - CustomWindowAction Calculator

extension WindowAction.CustomWindowAction: WindowActionCalculator {
    // 实现已移至 CustomWindowActionCalculator.swift
    // 这里保持接口,实际计算在独立文件中
}

// MARK: - Helper Extensions

// Note: clamped(to:) removed - use WindowFrameUtility.clamp(_:to:) instead
