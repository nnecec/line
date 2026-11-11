//
//  WindowInfoMatchPolicy.swift
//  Line
//

import CoreGraphics

/// Pure matching rules used when a CG window entry must be paired with AX windows.
enum WindowInfoMatchPolicy {
    static func matches(
        targetFrame: CGRect,
        candidatePosition: CGPoint?,
        candidateSize: CGSize?,
        tolerance: CGFloat = 0
    ) -> Bool {
        guard let candidatePosition, let candidateSize else { return false }
        return abs(candidatePosition.x - targetFrame.origin.x) <= tolerance &&
            abs(candidatePosition.y - targetFrame.origin.y) <= tolerance &&
            abs(candidateSize.width - targetFrame.size.width) <= tolerance &&
            abs(candidateSize.height - targetFrame.size.height) <= tolerance
    }
}
