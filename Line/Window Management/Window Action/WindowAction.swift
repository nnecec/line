//
//  WindowAction.swift
//  Line
//
//  Created via architecture refactor on 2026-07-02.
//
//  Type-safe ADT (Algebraic Data Type) representation of window actions.
//  Each case carries exactly the data it needs, enforced at compile time.
//

import AppKit
import CoreGraphics
import Foundation

/// Type-safe representation of window actions.
/// Each case carries exactly the data it needs, enforced at compile time.
enum WindowAction: Hashable, Equatable {
    case standard(StandardWindowAction)
    case incremental(IncrementalAction)
    case focus(FocusAction)
    case screen(ScreenSwitchAction)
    case custom(CustomWindowAction)
    case cycle([WindowAction])
    case stash(name: String, edge: StashEdge)
    case special(SpecialAction)

    // MARK: - Standard Actions (proportional frame calculations)

    enum StandardWindowAction: Hashable, Equatable {
        case proportional(ProportionalLayout)
        case maximize
        case almostMaximize
        case fullscreen
        case maximizeHeight
        case maximizeWidth
        case fillAvailableSpace
        case center(CenterMode)

        enum CenterMode: Hashable, Equatable {
            case macOS // macOS-style center with Y offset
            case geometric // true geometric center
        }
    }

    // MARK: - Incremental Actions (adjust current frame)

    enum IncrementalAction: Hashable, Equatable {
        // Size adjustment
        case larger
        case smaller
        case scaleUp
        case scaleDown

        // Move
        case moveUp
        case moveDown
        case moveLeft
        case moveRight

        // Grow (expand from specific edge)
        case growTop
        case growBottom
        case growLeft
        case growRight
        case growHorizontal
        case growVertical

        // Shrink (contract from specific edge)
        case shrinkTop
        case shrinkBottom
        case shrinkLeft
        case shrinkRight
        case shrinkHorizontal
        case shrinkVertical
    }

    // MARK: - Focus Actions (window focus, no frame calculation)

    enum FocusAction: Hashable, Equatable {
        case focusUp
        case focusDown
        case focusLeft
        case focusRight
        case focusNextInStack

        var direction: NavigationDirection? {
            switch self {
            case .focusLeft: .left
            case .focusRight: .right
            case .focusUp: .top
            case .focusDown: .bottom
            case .focusNextInStack: nil
            }
        }
    }

    // MARK: - Screen Switch Actions

    enum ScreenSwitchAction: Hashable, Equatable {
        case next
        case previous
        case left
        case right
        case top
        case bottom
    }

    // MARK: - Custom Actions (user-defined layout)

    struct CustomWindowAction: Hashable, Equatable {
        let name: String
        let unit: CustomWindowActionUnit
        let anchor: CustomWindowActionAnchor
        let sizeMode: CustomWindowActionSizeMode
        let width: Double?
        let height: Double?
        let positionMode: CustomWindowActionPositionMode
        let xPoint: Double?
        let yPoint: Double?
    }

    // MARK: - Special Actions (lifecycle operations)

    enum SpecialAction: Hashable, Equatable {
        case undo
        case initialFrame
        case hide
        case minimize
        case minimizeOthers
        case noAction
        case noSelection
    }
}

// MARK: - ProportionalLayout

/// Represents a frame as proportions of the available bounds (0.0 to 1.0).
/// Used for standard window positions like halves, thirds, quarters.
struct ProportionalLayout: Hashable, Equatable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat

    // MARK: - Predefined Layouts (Halves)

    static let topHalf = ProportionalLayout(x: 0, y: 0, width: 1.0, height: 0.5)
    static let rightHalf = ProportionalLayout(x: 0.5, y: 0, width: 0.5, height: 1.0)
    static let bottomHalf = ProportionalLayout(x: 0, y: 0.5, width: 1.0, height: 0.5)
    static let leftHalf = ProportionalLayout(x: 0, y: 0, width: 0.5, height: 1.0)
    static let horizontalCenterHalf = ProportionalLayout(x: 0.25, y: 0, width: 0.5, height: 1.0)
    static let verticalCenterHalf = ProportionalLayout(x: 0, y: 0.25, width: 1.0, height: 0.5)

    // MARK: - Predefined Layouts (Quarters)

    static let topLeftQuarter = ProportionalLayout(x: 0, y: 0, width: 0.5, height: 0.5)
    static let topRightQuarter = ProportionalLayout(x: 0.5, y: 0, width: 0.5, height: 0.5)
    static let bottomRightQuarter = ProportionalLayout(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
    static let bottomLeftQuarter = ProportionalLayout(x: 0, y: 0.5, width: 0.5, height: 0.5)

    // MARK: - Predefined Layouts (Horizontal Thirds)

    static let rightThird = ProportionalLayout(x: 2.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1.0)
    static let rightTwoThirds = ProportionalLayout(x: 1.0 / 3.0, y: 0, width: 2.0 / 3.0, height: 1.0)
    static let horizontalCenterThird = ProportionalLayout(x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1.0)
    static let leftThird = ProportionalLayout(x: 0, y: 0, width: 1.0 / 3.0, height: 1.0)
    static let leftTwoThirds = ProportionalLayout(x: 0, y: 0, width: 2.0 / 3.0, height: 1.0)

    // MARK: - Predefined Layouts (Vertical Thirds)

    static let topThird = ProportionalLayout(x: 0, y: 0, width: 1.0, height: 1.0 / 3.0)
    static let topTwoThirds = ProportionalLayout(x: 0, y: 0, width: 1.0, height: 2.0 / 3.0)
    static let verticalCenterThird = ProportionalLayout(x: 0, y: 1.0 / 3.0, width: 1.0, height: 1.0 / 3.0)
    static let bottomThird = ProportionalLayout(x: 0, y: 2.0 / 3.0, width: 1.0, height: 1.0 / 3.0)
    static let bottomTwoThirds = ProportionalLayout(x: 0, y: 1.0 / 3.0, width: 1.0, height: 2.0 / 3.0)

    // MARK: - Predefined Layouts (Horizontal Fourths)

    static let firstFourth = ProportionalLayout(x: 0, y: 0, width: 0.25, height: 1.0)
    static let secondFourth = ProportionalLayout(x: 0.25, y: 0, width: 0.25, height: 1.0)
    static let thirdFourth = ProportionalLayout(x: 0.5, y: 0, width: 0.25, height: 1.0)
    static let fourthFourth = ProportionalLayout(x: 0.75, y: 0, width: 0.25, height: 1.0)
    static let leftThreeFourths = ProportionalLayout(x: 0, y: 0, width: 0.75, height: 1.0)
    static let rightThreeFourths = ProportionalLayout(x: 0.25, y: 0, width: 0.75, height: 1.0)

    // MARK: - Frame Calculation

    func calculateFrame(in bounds: CGRect) -> CGRect {
        CGRect(
            x: bounds.origin.x + bounds.width * x,
            y: bounds.origin.y + bounds.height * y,
            width: bounds.width * width,
            height: bounds.height * height
        )
    }
}

// MARK: - WindowAction Extensions

extension WindowAction {
    /// Whether this action can be repeated (e.g., incremental actions that adjust the current frame).
    /// Actions that manipulate the existing window frame can be repeated by holding down the keybind.
    var canRepeat: Bool {
        switch self {
        case .incremental:
            // All incremental actions can repeat (larger, smaller, move, grow, shrink)
            true
        case .focus, .screen:
            // Focus and screen switching should not repeat
            false
        case .standard, .custom, .stash, .special:
            // Standard layouts, custom actions, stash, and special actions don't repeat
            false
        case .cycle:
            // Cycle actions don't repeat automatically
            false
        }
    }

    /// Whether inner padding should be applied to this action.
    /// Inner padding is applied to sides that don't touch the bounds edges.
    var isInnerPaddingApplicable: Bool {
        switch self {
        case let .standard(standard):
            // Padding applies to most standard actions except center and fullscreen
            switch standard {
            case .center, .fullscreen:
                false
            default:
                true
            }
        case .custom:
            true
        case .incremental, .focus, .screen, .stash, .special, .cycle:
            false
        }
    }
}

// MARK: - BoundWindowAction Extensions

extension BoundWindowAction {
    /// Whether this bound action can be repeated.
    /// Delegates to the underlying WindowAction's canRepeat property.
    var canRepeat: Bool {
        action.canRepeat
    }
}
