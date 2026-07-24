//
//  StashSessionFramePolicy.swift
//  Line
//
//  Layout-frame selection for sessions opened on a stashed window.
//  Prefer the stash revealed frame when present so geometry matches the
//  on-screen peeks/reveals rather than the off-screen stashed AX frame.
//
//  Call sites should prefer WindowResizeExecution.bootstrap, which owns this
//  rule. This type remains for direct unit tests of the coalescing rule.
//

import CoreGraphics
import Foundation

enum StashSessionFramePolicy {
    /// Frame to use for Window Resize Execution layout math.
    /// - Parameter revealedFrame: Stash revealed frame when the window is managed as stashed.
    /// - Parameter currentFrame: Live accessibility frame (often the stashed edge position).
    static func frameForLayout(revealedFrame: CGRect?, currentFrame: CGRect) -> CGRect {
        WindowResizeExecution.layoutFrame(revealedFrame: revealedFrame, currentFrame: currentFrame)
    }
}
