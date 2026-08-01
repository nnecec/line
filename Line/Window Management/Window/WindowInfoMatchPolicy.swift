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
        candidateSize: CGSize?
    ) -> Bool {
        guard let candidatePosition, let candidateSize else { return false }
        return candidatePosition == targetFrame.origin && candidateSize == targetFrame.size
    }
}
