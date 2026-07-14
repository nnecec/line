//
//  PreviewStartingPosition.swift
//  Line
//
//  Created by nnecec on 2025-05-30.
//

import Defaults
import Foundation

/// An enum to represent the starting position of the preview window when it is initially opened.
enum PreviewStartingPosition: String, Defaults.Serializable {
    /// The preview window will open at the center of the screen.
    case screenCenter

    /// The preview window will open at the center of the first action.
    case actionCenter
}
