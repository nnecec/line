//
//  WindowFrameUtility.swift
//  Line
//
//  Created by Claude on 2026-07-16.
//

import SwiftUI

/// Centralized utilities for window frame calculations and boundary checks.
/// Consolidates repeated logic from CGGeometry extensions, calculators, and animation code.
enum WindowFrameUtility {

    // MARK: - Tolerance Values

    /// Standard tolerance values for approximate equality checks
    enum Tolerance {
        /// Default tolerance for general frame comparisons (10 points)
        static let `default`: CGFloat = 10

        /// Stricter tolerance for animation frame comparisons (2 points)
        static let animation: CGFloat = 2

        /// Very strict tolerance for precise comparisons (1 point)
        static let strict: CGFloat = 1
    }

    // MARK: - Boundary Adjustment

    /// Pushes a frame inside the given bounds by adjusting only its origin.
    /// Does not modify the frame's size.
    ///
    /// - Parameters:
    ///   - frame: The frame to adjust
    ///   - bounds: The bounding rectangle
    /// - Returns: A new frame with origin adjusted to fit within bounds
    static func pushInside(_ frame: CGRect, bounds: CGRect) -> CGRect {
        var result = frame

        if result.minX < bounds.minX {
            result.origin.x = bounds.minX
        }

        if result.minY < bounds.minY {
            result.origin.y = bounds.minY
        }

        if result.maxX > bounds.maxX {
            result.origin.x = bounds.maxX - result.width
        }

        if result.maxY > bounds.maxY {
            result.origin.y = bounds.maxY - result.height
        }

        return result
    }

    /// Clamps a frame to fit within the given bounds by adjusting both size and origin.
    /// First shrinks the size if needed, then adjusts the origin.
    ///
    /// - Parameters:
    ///   - frame: The frame to clamp
    ///   - bounds: The bounding rectangle
    /// - Returns: A new frame that fits entirely within bounds
    static func clamp(_ frame: CGRect, to bounds: CGRect) -> CGRect {
        var clamped = frame

        // Clamp size first
        if clamped.width > bounds.width {
            clamped.size.width = bounds.width
        }
        if clamped.height > bounds.height {
            clamped.size.height = bounds.height
        }

        // Then clamp position
        if clamped.minX < bounds.minX {
            clamped.origin.x = bounds.minX
        }
        if clamped.maxX > bounds.maxX {
            clamped.origin.x = bounds.maxX - clamped.width
        }
        if clamped.minY < bounds.minY {
            clamped.origin.y = bounds.minY
        }
        if clamped.maxY > bounds.maxY {
            clamped.origin.y = bounds.maxY - clamped.height
        }

        return clamped
    }

    // MARK: - Edge Detection

    /// Determines which edges of a frame are touching (within tolerance) the bounds.
    ///
    /// - Parameters:
    ///   - frame: The frame to check
    ///   - bounds: The bounding rectangle
    ///   - tolerance: The tolerance for edge proximity (default: Tolerance.default)
    /// - Returns: A set of edges that are touching the bounds
    static func edgesTouchingBounds(
        _ frame: CGRect,
        _ bounds: CGRect,
        tolerance: CGFloat = Tolerance.default
    ) -> Edge.Set {
        var result: Edge.Set = []

        if abs(frame.minX - bounds.minX) < tolerance {
            result.insert(.leading)
        }

        if abs(frame.minY - bounds.minY) < tolerance {
            result.insert(.top)
        }

        if abs(frame.maxX - bounds.maxX) < tolerance {
            result.insert(.trailing)
        }

        if abs(frame.maxY - bounds.maxY) < tolerance {
            result.insert(.bottom)
        }

        return result
    }

    // MARK: - macOS Styling

    /// Calculates the Y offset for macOS-style center positioning.
    /// macOS centers windows slightly above the mathematical center for better visual balance.
    ///
    /// - Parameter height: The height of the screen or bounds
    /// - Returns: The Y offset (height / 10)
    static func macOSCenterYOffset(for height: CGFloat) -> CGFloat {
        height / 10
    }

    // MARK: - Frame Change Detection

    /// Checks if a frame has moved from one position to another.
    ///
    /// - Parameters:
    ///   - from: The original frame
    ///   - to: The new frame
    ///   - tolerance: The tolerance for position comparison (default: Tolerance.default)
    /// - Returns: `true` if the frame has moved beyond the tolerance
    static func hasMoved(
        from: CGRect,
        to: CGRect,
        tolerance: CGFloat = Tolerance.default
    ) -> Bool {
        abs(from.origin.x - to.origin.x) >= tolerance ||
        abs(from.origin.y - to.origin.y) >= tolerance
    }

    /// Checks if a frame has been resized.
    ///
    /// - Parameters:
    ///   - from: The original frame
    ///   - to: The new frame
    ///   - tolerance: The tolerance for size comparison (default: Tolerance.default)
    /// - Returns: `true` if the frame has been resized beyond the tolerance
    static func hasResized(
        from: CGRect,
        to: CGRect,
        tolerance: CGFloat = Tolerance.default
    ) -> Bool {
        abs(from.width - to.width) >= tolerance ||
        abs(from.height - to.height) >= tolerance
    }
}
