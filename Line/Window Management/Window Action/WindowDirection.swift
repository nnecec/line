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
