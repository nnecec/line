//
//  StashSessionFramePolicy.swift
//  Line
//
//  Pure policy for choosing the layout frame when opening a session
//  for a possibly-stashed window.
//

import CoreGraphics
import Foundation

enum StashSessionFramePolicy {
    /// Returns the frame that layout math should use when opening a session.
    /// Prefer the stash revealed frame when present; otherwise the live AX frame.
    static func frameForLayout(revealedFrame: CGRect?, currentFrame: CGRect) -> CGRect {
        revealedFrame ?? currentFrame
    }
}
