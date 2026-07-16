//
//  WindowDirection.swift
//  Line
//
//  Created by nnecec on 2023-06-14.
//

import Defaults
import SwiftUI

/// Enum that stores all possible resizing options
enum WindowDirection: String, CaseIterable, Identifiable, Codable {
    var id: Self { self }

    /// "Empty" actions.
    /// `noAction` is explicitly chosen or user-bound.
    /// `noSelection` represents the initial action-less state and opens grid selection when used as a starting action.
    case noAction = "NoAction", noSelection = "NoSelection"

    // General Actions
    case maximize = "Maximize", almostMaximize = "AlmostMaximize", fullscreen = "Fullscreen"
    case maximizeHeight = "MaximizeHeight", maximizeWidth = "MaximizeWidth", fillAvailableSpace = "FillAvailableSpace"
    case undo = "Undo", initialFrame = "InitialFrame", hide = "Hide", minimize = "Minimize", minimizeOthers = "MinimizeOthers"
    case macOSCenter = "MacOSCenter", center = "Center"

    // Halves
    case topHalf = "TopHalf", rightHalf = "RightHalf", bottomHalf = "BottomHalf", leftHalf = "LeftHalf"
    case horizontalCenterHalf = "HorizontalCenterHalf", verticalCenterHalf = "VerticalCenterHalf"

    // Quarters
    case topLeftQuarter = "TopLeftQuarter", topRightQuarter = "TopRightQuarter"
    case bottomRightQuarter = "BottomRightQuarter", bottomLeftQuarter = "BottomLeftQuarter"

    // Horizontal Thirds
    case rightThird = "RightThird", rightTwoThirds = "RightTwoThirds"
    case horizontalCenterThird = "HorizontalCenterThird"
    case leftThird = "LeftThird", leftTwoThirds = "LeftTwoThirds"

    // Horizontal Fourths
    case firstFourth = "FirstFourth", secondFourth = "SecondFourth", thirdFourth = "ThirdFourth", fourthFourth = "FourthFourth"
    case leftThreeFourths = "LeftThreeFourths", rightThreeFourths = "RightThreeFourths"

    // Vertical Thirds
    case topThird = "TopThird", topTwoThirds = "TopTwoThirds"
    case verticalCenterThird = "VerticalCenterThird"
    case bottomThird = "BottomThird", bottomTwoThirds = "BottomTwoThirds"

    /// Screen Switching
    case nextScreen = "NextScreen", previousScreen = "PreviousScreen", leftScreen = "LeftScreen", rightScreen = "RightScreen", topScreen = "TopScreen", bottomScreen = "BottomScreen"

    // Size Adjustment
    case larger = "Larger", smaller = "Smaller"
    case scaleUp = "ScaleUp", scaleDown = "ScaleDown"

    /// Shrink
    case shrinkTop = "ShrinkTop", shrinkBottom = "ShrinkBottom", shrinkRight = "ShrinkRight", shrinkLeft = "ShrinkLeft", shrinkHorizontal = "ShrinkHorizontal", shrinkVertical = "ShrinkVertical"

    /// Grow
    case growTop = "GrowTop", growBottom = "GrowBottom", growRight = "GrowRight", growLeft = "GrowLeft", growHorizontal = "GrowHorizontal", growVertical = "GrowVertical"

    /// Move
    case moveUp = "MoveUp", moveDown = "MoveDown", moveRight = "MoveRight", moveLeft = "MoveLeft"

    /// Focus
    case focusUp = "FocusUp", focusDown = "FocusDown", focusRight = "FocusRight", focusLeft = "FocusLeft", focusNextInStack = "FocusNextInStack"

    // Stash
    case stash = "Stash"
    case unstash = "Unstash"

    /// Custom Actions
    case custom = "Custom", cycle = "Cycle"

    // These are used in the menubar resize submenu & keybind configuration
    static var general: [WindowDirection] { [.fullscreen, .maximize, .almostMaximize, .maximizeHeight, .maximizeWidth, .fillAvailableSpace, .center, .macOSCenter, .minimize, .minimizeOthers, .hide] }
    static var halves: [WindowDirection] { [.topHalf, .verticalCenterHalf, .bottomHalf, .leftHalf, .horizontalCenterHalf, .rightHalf] }
    static var quarters: [WindowDirection] { [.topLeftQuarter, .topRightQuarter, .bottomLeftQuarter, .bottomRightQuarter] }
    static var horizontalThirds: [WindowDirection] { [.rightThird, .rightTwoThirds, .horizontalCenterThird, .leftTwoThirds, .leftThird] }
    static var verticalThirds: [WindowDirection] { [.topThird, .topTwoThirds, .verticalCenterThird, .bottomTwoThirds, .bottomThird] }
    static var horizontalFourths: [WindowDirection] { [.firstFourth, .secondFourth, .thirdFourth, .fourthFourth, .leftThreeFourths, .rightThreeFourths] }
    static var screenSwitching: [WindowDirection] { [.nextScreen, .previousScreen, .leftScreen, .rightScreen, .topScreen, .bottomScreen] }
    static var sizeAdjustment: [WindowDirection] { [.larger, .smaller, .scaleUp, .scaleDown] }
    static var shrink: [WindowDirection] { [.shrinkTop, .shrinkBottom, .shrinkRight, .shrinkLeft, .shrinkHorizontal, .shrinkVertical] }
    static var grow: [WindowDirection] { [.growTop, .growBottom, .growRight, .growLeft, .growHorizontal, .growVertical] }
    static var move: [WindowDirection] { [.moveUp, .moveDown, .moveRight, .moveLeft] }
    static var focus: [WindowDirection] { [.focusUp, .focusDown, .focusRight, .focusLeft, .focusNextInStack] }
    static var more: [WindowDirection] { [.initialFrame, .undo, .custom, .cycle] }

    // Computed properties for checking conditions
    var isNoOp: Bool { [.noSelection, .noAction].contains(self) }
    var willChangeScreen: Bool { WindowDirection.screenSwitching.contains(self) }
    var willAdjustSize: Bool { WindowDirection.sizeAdjustment.contains(self) }
    var willShrink: Bool { WindowDirection.shrink.contains(self) }
    var willGrow: Bool { WindowDirection.grow.contains(self) }
    var willMove: Bool { WindowDirection.move.contains(self) }
    var willFocusWindow: Bool { WindowDirection.focus.contains(self) }
    var willCenter: Bool { [.center, .macOSCenter, .verticalCenterHalf, .horizontalCenterHalf].contains(self) }
    var isCustomizable: Bool { [.custom, .stash].contains(self) }

    var frameMultiplyValues: CGRect? {
        switch self {
        case .maximize: .init(x: 0, y: 0, width: 1.0, height: 1.0)
        case .almostMaximize: .init(x: 0.5 / 10.0, y: 0.5 / 10.0, width: 9.0 / 10.0, height: 9.0 / 10.0)
        case .fullscreen: .init(x: 0, y: 0, width: 1.0, height: 1.0)
        // Halves
        case .topHalf: .init(x: 0, y: 0, width: 1.0, height: 1.0 / 2.0)
        case .rightHalf: .init(x: 1.0 / 2.0, y: 0, width: 1.0 / 2.0, height: 1.0)
        case .bottomHalf: .init(x: 0, y: 1.0 / 2.0, width: 1.0, height: 1.0 / 2.0)
        case .leftHalf: .init(x: 0, y: 0, width: 1.0 / 2.0, height: 1.0)
        case .horizontalCenterHalf: .init(x: 1.0 / 4.0, y: 0, width: 1.0 / 2.0, height: 1.0)
        case .verticalCenterHalf: .init(x: 0, y: 1.0 / 4.0, width: 1.0, height: 1.0 / 2.0)
        // Quarters
        case .topLeftQuarter: .init(x: 0, y: 0, width: 1.0 / 2.0, height: 1.0 / 2.0)
        case .topRightQuarter: .init(x: 1.0 / 2.0, y: 0, width: 1.0 / 2.0, height: 1.0 / 2.0)
        case .bottomRightQuarter: .init(x: 1.0 / 2.0, y: 1.0 / 2.0, width: 1.0 / 2.0, height: 1.0 / 2.0)
        case .bottomLeftQuarter: .init(x: 0, y: 1.0 / 2.0, width: 1.0 / 2.0, height: 1.0 / 2.0)
        // Thirds (Horizontal)
        case .rightThird: .init(x: 2.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1.0)
        case .rightTwoThirds: .init(x: 1.0 / 3.0, y: 0, width: 2.0 / 3.0, height: 1.0)
        case .horizontalCenterThird: .init(x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1.0)
        case .leftThird: .init(x: 0, y: 0, width: 1.0 / 3.0, height: 1.0)
        case .leftTwoThirds: .init(x: 0, y: 0, width: 2.0 / 3.0, height: 1.0)
        // Thirds (Vertical)
        case .topThird: .init(x: 0, y: 0, width: 1.0, height: 1.0 / 3.0)
        case .topTwoThirds: .init(x: 0, y: 0, width: 1.0, height: 2.0 / 3.0)
        case .verticalCenterThird: .init(x: 0, y: 1.0 / 3.0, width: 1.0, height: 1.0 / 3.0)
        case .bottomThird: .init(x: 0, y: 2.0 / 3.0, width: 1.0, height: 1.0 / 3.0)
        case .bottomTwoThirds: .init(x: 0, y: 1.0 / 3.0, width: 1.0, height: 2.0 / 3.0)
        // Fourths (Horizontal)
        case .firstFourth: .init(x: 0, y: 0, width: 1.0 / 4.0, height: 1.0)
        case .secondFourth: .init(x: 1.0 / 4.0, y: 0, width: 1.0 / 4.0, height: 1.0)
        case .thirdFourth: .init(x: 2.0 / 4.0, y: 0, width: 1.0 / 4.0, height: 1.0)
        case .fourthFourth: .init(x: 3.0 / 4.0, y: 0, width: 1.0 / 4.0, height: 1.0)
        case .leftThreeFourths: .init(x: 0, y: 0, width: 3.0 / 4.0, height: 1.0)
        case .rightThreeFourths: .init(x: 1.0 / 4.0, y: 0, width: 3.0 / 4.0, height: 1.0)
        default: nil
        }
    }

    var focusDirection: NavigationDirection? {
        switch self {
        case .focusLeft: .left
        case .focusRight: .right
        case .focusUp: .top
        case .focusDown: .bottom
        default: nil
        }
    }

    /// Convert WindowDirection to WindowAction.
    func toWindowAction() -> WindowAction {
        switch self {
        // Special actions
        case .noAction: .special(.noAction)
        case .noSelection: .special(.noSelection)
        case .hide: .special(.hide)
        case .minimize: .special(.minimize)
        case .minimizeOthers: .special(.minimizeOthers)
        case .undo: .special(.undo)
        case .initialFrame: .special(.initialFrame)
        // Standard actions - proportional
        case .maximize: .standard(.maximize)
        case .almostMaximize: .standard(.almostMaximize)
        case .fullscreen: .standard(.fullscreen)
        case .maximizeHeight: .standard(.maximizeHeight)
        case .maximizeWidth: .standard(.maximizeWidth)
        case .fillAvailableSpace: .standard(.fillAvailableSpace)
        case .center: .standard(.center(.geometric))
        case .macOSCenter: .standard(.center(.macOS))
        // Halves
        case .topHalf: .standard(.proportional(.topHalf))
        case .rightHalf: .standard(.proportional(.rightHalf))
        case .bottomHalf: .standard(.proportional(.bottomHalf))
        case .leftHalf: .standard(.proportional(.leftHalf))
        case .horizontalCenterHalf: .standard(.proportional(.horizontalCenterHalf))
        case .verticalCenterHalf: .standard(.proportional(.verticalCenterHalf))
        // Quarters
        case .topLeftQuarter: .standard(.proportional(.topLeftQuarter))
        case .topRightQuarter: .standard(.proportional(.topRightQuarter))
        case .bottomRightQuarter: .standard(.proportional(.bottomRightQuarter))
        case .bottomLeftQuarter: .standard(.proportional(.bottomLeftQuarter))
        // Thirds
        case .rightThird: .standard(.proportional(.rightThird))
        case .rightTwoThirds: .standard(.proportional(.rightTwoThirds))
        case .horizontalCenterThird: .standard(.proportional(.horizontalCenterThird))
        case .leftThird: .standard(.proportional(.leftThird))
        case .leftTwoThirds: .standard(.proportional(.leftTwoThirds))
        case .topThird: .standard(.proportional(.topThird))
        case .topTwoThirds: .standard(.proportional(.topTwoThirds))
        case .verticalCenterThird: .standard(.proportional(.verticalCenterThird))
        case .bottomThird: .standard(.proportional(.bottomThird))
        case .bottomTwoThirds: .standard(.proportional(.bottomTwoThirds))
        // Fourths
        case .firstFourth: .standard(.proportional(.firstFourth))
        case .secondFourth: .standard(.proportional(.secondFourth))
        case .thirdFourth: .standard(.proportional(.thirdFourth))
        case .fourthFourth: .standard(.proportional(.fourthFourth))
        case .leftThreeFourths: .standard(.proportional(.leftThreeFourths))
        case .rightThreeFourths: .standard(.proportional(.rightThreeFourths))
        // Screen switching
        case .nextScreen: .screen(.next)
        case .previousScreen: .screen(.previous)
        case .leftScreen: .screen(.left)
        case .rightScreen: .screen(.right)
        case .topScreen: .screen(.top)
        case .bottomScreen: .screen(.bottom)
        // Incremental - size
        case .larger: .incremental(.larger)
        case .smaller: .incremental(.smaller)
        case .scaleUp: .incremental(.scaleUp)
        case .scaleDown: .incremental(.scaleDown)
        // Incremental - move
        case .moveUp: .incremental(.moveUp)
        case .moveDown: .incremental(.moveDown)
        case .moveRight: .incremental(.moveRight)
        case .moveLeft: .incremental(.moveLeft)
        // Incremental - grow
        case .growTop: .incremental(.growTop)
        case .growBottom: .incremental(.growBottom)
        case .growRight: .incremental(.growRight)
        case .growLeft: .incremental(.growLeft)
        case .growHorizontal: .incremental(.growHorizontal)
        case .growVertical: .incremental(.growVertical)
        // Incremental - shrink
        case .shrinkTop: .incremental(.shrinkTop)
        case .shrinkBottom: .incremental(.shrinkBottom)
        case .shrinkRight: .incremental(.shrinkRight)
        case .shrinkLeft: .incremental(.shrinkLeft)
        case .shrinkHorizontal: .incremental(.shrinkHorizontal)
        case .shrinkVertical: .incremental(.shrinkVertical)
        // Focus
        case .focusUp: .focus(.focusUp)
        case .focusDown: .focus(.focusDown)
        case .focusRight: .focus(.focusRight)
        case .focusLeft: .focus(.focusLeft)
        case .focusNextInStack: .focus(.focusNextInStack)
        // Custom/Stash - these need additional context
        case .custom: .special(.noAction) // Placeholder - needs name
        case .stash: .stash(name: "Stash", edge: .left)
        case .unstash: .special(.noAction) // Placeholder
        case .cycle: .special(.noAction) // Placeholder - needs actions array
        }
    }
}

extension WindowDirection: CustomDebugStringConvertible {
    var debugDescription: String {
        rawValue
    }
}

extension WindowDirection {
    /// Localized display name for the action
    var localizedName: String {
        switch self {
        // Empty actions
        case .noAction: String(localized: "No Action", comment: "Window action name")
        case .noSelection: String(localized: "No Selection", comment: "Window action name")

        // General Actions
        case .maximize: String(localized: "Maximize", comment: "Window action name")
        case .almostMaximize: String(localized: "Almost Maximize", comment: "Window action name")
        case .fullscreen: String(localized: "Fullscreen", comment: "Window action name")
        case .maximizeHeight: String(localized: "Maximize Height", comment: "Window action name")
        case .maximizeWidth: String(localized: "Maximize Width", comment: "Window action name")
        case .fillAvailableSpace: String(localized: "Fill Available Space", comment: "Window action name")
        case .undo: String(localized: "Undo", comment: "Window action name")
        case .initialFrame: String(localized: "Initial Frame", comment: "Window action name")
        case .hide: String(localized: "Hide", comment: "Window action name")
        case .minimize: String(localized: "Minimize", comment: "Window action name")
        case .minimizeOthers: String(localized: "Minimize Others", comment: "Window action name")
        case .macOSCenter: String(localized: "macOS Center", comment: "Window action name")
        case .center: String(localized: "Center", comment: "Window action name")

        // Halves
        case .topHalf: String(localized: "Top Half", comment: "Window action name")
        case .rightHalf: String(localized: "Right Half", comment: "Window action name")
        case .bottomHalf: String(localized: "Bottom Half", comment: "Window action name")
        case .leftHalf: String(localized: "Left Half", comment: "Window action name")
        case .horizontalCenterHalf: String(localized: "Horizontal Center Half", comment: "Window action name")
        case .verticalCenterHalf: String(localized: "Vertical Center Half", comment: "Window action name")

        // Quarters
        case .topLeftQuarter: String(localized: "Top Left Quarter", comment: "Window action name")
        case .topRightQuarter: String(localized: "Top Right Quarter", comment: "Window action name")
        case .bottomRightQuarter: String(localized: "Bottom Right Quarter", comment: "Window action name")
        case .bottomLeftQuarter: String(localized: "Bottom Left Quarter", comment: "Window action name")

        // Horizontal Thirds
        case .rightThird: String(localized: "Right Third", comment: "Window action name")
        case .rightTwoThirds: String(localized: "Right Two Thirds", comment: "Window action name")
        case .horizontalCenterThird: String(localized: "Horizontal Center Third", comment: "Window action name")
        case .leftThird: String(localized: "Left Third", comment: "Window action name")
        case .leftTwoThirds: String(localized: "Left Two Thirds", comment: "Window action name")

        // Horizontal Fourths
        case .firstFourth: String(localized: "First Fourth", comment: "Window action name")
        case .secondFourth: String(localized: "Second Fourth", comment: "Window action name")
        case .thirdFourth: String(localized: "Third Fourth", comment: "Window action name")
        case .fourthFourth: String(localized: "Fourth Fourth", comment: "Window action name")
        case .leftThreeFourths: String(localized: "Left Three Fourths", comment: "Window action name")
        case .rightThreeFourths: String(localized: "Right Three Fourths", comment: "Window action name")

        // Vertical Thirds
        case .topThird: String(localized: "Top Third", comment: "Window action name")
        case .topTwoThirds: String(localized: "Top Two Thirds", comment: "Window action name")
        case .verticalCenterThird: String(localized: "Vertical Center Third", comment: "Window action name")
        case .bottomThird: String(localized: "Bottom Third", comment: "Window action name")
        case .bottomTwoThirds: String(localized: "Bottom Two Thirds", comment: "Window action name")

        // Screen Switching
        case .nextScreen: String(localized: "Next Screen", comment: "Window action name")
        case .previousScreen: String(localized: "Previous Screen", comment: "Window action name")
        case .leftScreen: String(localized: "Left Screen", comment: "Window action name")
        case .rightScreen: String(localized: "Right Screen", comment: "Window action name")
        case .topScreen: String(localized: "Top Screen", comment: "Window action name")
        case .bottomScreen: String(localized: "Bottom Screen", comment: "Window action name")

        // Size Adjustment
        case .larger: String(localized: "Larger", comment: "Window action name")
        case .smaller: String(localized: "Smaller", comment: "Window action name")
        case .scaleUp: String(localized: "Scale Up", comment: "Window action name")
        case .scaleDown: String(localized: "Scale Down", comment: "Window action name")

        // Shrink
        case .shrinkTop: String(localized: "Shrink Top", comment: "Window action name")
        case .shrinkBottom: String(localized: "Shrink Bottom", comment: "Window action name")
        case .shrinkRight: String(localized: "Shrink Right", comment: "Window action name")
        case .shrinkLeft: String(localized: "Shrink Left", comment: "Window action name")
        case .shrinkHorizontal: String(localized: "Shrink Horizontal", comment: "Window action name")
        case .shrinkVertical: String(localized: "Shrink Vertical", comment: "Window action name")

        // Grow
        case .growTop: String(localized: "Grow Top", comment: "Window action name")
        case .growBottom: String(localized: "Grow Bottom", comment: "Window action name")
        case .growRight: String(localized: "Grow Right", comment: "Window action name")
        case .growLeft: String(localized: "Grow Left", comment: "Window action name")
        case .growHorizontal: String(localized: "Grow Horizontal", comment: "Window action name")
        case .growVertical: String(localized: "Grow Vertical", comment: "Window action name")

        // Move
        case .moveUp: String(localized: "Move Up", comment: "Window action name")
        case .moveDown: String(localized: "Move Down", comment: "Window action name")
        case .moveRight: String(localized: "Move Right", comment: "Window action name")
        case .moveLeft: String(localized: "Move Left", comment: "Window action name")

        // Focus
        case .focusUp: String(localized: "Focus Up", comment: "Window action name")
        case .focusDown: String(localized: "Focus Down", comment: "Window action name")
        case .focusRight: String(localized: "Focus Right", comment: "Window action name")
        case .focusLeft: String(localized: "Focus Left", comment: "Window action name")
        case .focusNextInStack: String(localized: "Focus Next in Stack", comment: "Window action name")

        // Stash
        case .stash: String(localized: "Stash", comment: "Window action name")
        case .unstash: String(localized: "Unstash", comment: "Window action name")

        // Custom Actions
        case .custom: String(localized: "Custom", comment: "Window action name")
        case .cycle: String(localized: "Cycle", comment: "Window action name")
        }
    }
}
