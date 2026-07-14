//
//  WindowAction+Codable.swift
//  Line
//
//  Created via architecture refactor on 2026-07-02.
//
//  Custom Codable implementation for WindowAction.
//  Maintains backward compatibility by encoding/decoding to the legacy SavedWindowActionFormat.
//  This allows existing JSON configuration files to be read without migration.
//

import CoreGraphics
import Foundation

// MARK: - Codable Implementation

extension WindowAction: Codable {
    private enum CodingKeys: String, CodingKey {
        case direction
        case name
        case unit
        case anchor
        case sizeMode
        case width
        case height
        case positionMode
        case xPoint
        case yPoint
        case cycle
        case stashEdge
    }

    /// Decodes from the legacy SavedWindowActionFormat.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let direction = try container.decode(WindowDirection.self, forKey: .direction)

        // Decode based on direction type
        switch direction {
        // Special actions
        case .noAction:
            self = .special(.noAction)
        case .noSelection:
            self = .special(.noSelection)
        case .undo:
            self = .special(.undo)
        case .initialFrame:
            self = .special(.initialFrame)
        case .hide:
            self = .special(.hide)
        case .minimize:
            self = .special(.minimize)
        case .minimizeOthers:
            self = .special(.minimizeOthers)
        // Standard actions - proportional
        case .topHalf:
            self = .standard(.proportional(.topHalf))
        case .rightHalf:
            self = .standard(.proportional(.rightHalf))
        case .bottomHalf:
            self = .standard(.proportional(.bottomHalf))
        case .leftHalf:
            self = .standard(.proportional(.leftHalf))
        case .horizontalCenterHalf:
            self = .standard(.proportional(.horizontalCenterHalf))
        case .verticalCenterHalf:
            self = .standard(.proportional(.verticalCenterHalf))
        case .topLeftQuarter:
            self = .standard(.proportional(.topLeftQuarter))
        case .topRightQuarter:
            self = .standard(.proportional(.topRightQuarter))
        case .bottomRightQuarter:
            self = .standard(.proportional(.bottomRightQuarter))
        case .bottomLeftQuarter:
            self = .standard(.proportional(.bottomLeftQuarter))
        case .rightThird:
            self = .standard(.proportional(.rightThird))
        case .rightTwoThirds:
            self = .standard(.proportional(.rightTwoThirds))
        case .horizontalCenterThird:
            self = .standard(.proportional(.horizontalCenterThird))
        case .leftThird:
            self = .standard(.proportional(.leftThird))
        case .leftTwoThirds:
            self = .standard(.proportional(.leftTwoThirds))
        case .topThird:
            self = .standard(.proportional(.topThird))
        case .topTwoThirds:
            self = .standard(.proportional(.topTwoThirds))
        case .verticalCenterThird:
            self = .standard(.proportional(.verticalCenterThird))
        case .bottomThird:
            self = .standard(.proportional(.bottomThird))
        case .bottomTwoThirds:
            self = .standard(.proportional(.bottomTwoThirds))
        case .firstFourth:
            self = .standard(.proportional(.firstFourth))
        case .secondFourth:
            self = .standard(.proportional(.secondFourth))
        case .thirdFourth:
            self = .standard(.proportional(.thirdFourth))
        case .fourthFourth:
            self = .standard(.proportional(.fourthFourth))
        case .leftThreeFourths:
            self = .standard(.proportional(.leftThreeFourths))
        case .rightThreeFourths:
            self = .standard(.proportional(.rightThreeFourths))
        // Standard actions - special maximize variants
        case .maximize:
            self = .standard(.maximize)
        case .almostMaximize:
            self = .standard(.almostMaximize)
        case .fullscreen:
            self = .standard(.fullscreen)
        case .maximizeHeight:
            self = .standard(.maximizeHeight)
        case .maximizeWidth:
            self = .standard(.maximizeWidth)
        case .fillAvailableSpace:
            self = .standard(.fillAvailableSpace)
        case .center:
            self = .standard(.center(.geometric))
        case .macOSCenter:
            self = .standard(.center(.macOS))
        // Incremental actions
        case .larger:
            self = .incremental(.larger)
        case .smaller:
            self = .incremental(.smaller)
        case .scaleUp:
            self = .incremental(.scaleUp)
        case .scaleDown:
            self = .incremental(.scaleDown)
        case .moveUp:
            self = .incremental(.moveUp)
        case .moveDown:
            self = .incremental(.moveDown)
        case .moveLeft:
            self = .incremental(.moveLeft)
        case .moveRight:
            self = .incremental(.moveRight)
        case .growTop:
            self = .incremental(.growTop)
        case .growBottom:
            self = .incremental(.growBottom)
        case .growLeft:
            self = .incremental(.growLeft)
        case .growRight:
            self = .incremental(.growRight)
        case .growHorizontal:
            self = .incremental(.growHorizontal)
        case .growVertical:
            self = .incremental(.growVertical)
        case .shrinkTop:
            self = .incremental(.shrinkTop)
        case .shrinkBottom:
            self = .incremental(.shrinkBottom)
        case .shrinkLeft:
            self = .incremental(.shrinkLeft)
        case .shrinkRight:
            self = .incremental(.shrinkRight)
        case .shrinkHorizontal:
            self = .incremental(.shrinkHorizontal)
        case .shrinkVertical:
            self = .incremental(.shrinkVertical)
        // Focus actions
        case .focusUp:
            self = .focus(.focusUp)
        case .focusDown:
            self = .focus(.focusDown)
        case .focusLeft:
            self = .focus(.focusLeft)
        case .focusRight:
            self = .focus(.focusRight)
        case .focusNextInStack:
            self = .focus(.focusNextInStack)
        // Screen switch actions
        case .nextScreen:
            self = .screen(.next)
        case .previousScreen:
            self = .screen(.previous)
        case .leftScreen:
            self = .screen(.left)
        case .rightScreen:
            self = .screen(.right)
        case .topScreen:
            self = .screen(.top)
        case .bottomScreen:
            self = .screen(.bottom)
        // Custom action - decode all properties
        case .custom:
            let name = try container.decode(String.self, forKey: .name)
            let unit = try container.decode(CustomWindowActionUnit.self, forKey: .unit)
            let anchor = try container.decode(CustomWindowActionAnchor.self, forKey: .anchor)
            let sizeMode = try container.decode(CustomWindowActionSizeMode.self, forKey: .sizeMode)
            let width = try container.decodeIfPresent(Double.self, forKey: .width)
            let height = try container.decodeIfPresent(Double.self, forKey: .height)
            let positionMode = try container.decode(CustomWindowActionPositionMode.self, forKey: .positionMode)
            let xPoint = try container.decodeIfPresent(Double.self, forKey: .xPoint)
            let yPoint = try container.decodeIfPresent(Double.self, forKey: .yPoint)

            self = .custom(CustomWindowAction(
                name: name,
                unit: unit,
                anchor: anchor,
                sizeMode: sizeMode,
                width: width,
                height: height,
                positionMode: positionMode,
                xPoint: xPoint,
                yPoint: yPoint
            ))
        // Cycle action - recursively decode nested actions
        case .cycle:
            let cycleActions = try container.decode([WindowAction].self, forKey: .cycle)
            self = .cycle(cycleActions)
        // Stash actions
        case .stash, .unstash:
            let name = try container.decodeIfPresent(String.self, forKey: .name) ?? "default"
            let edge = try container.decodeIfPresent(StashEdge.self, forKey: .stashEdge) ?? .left
            self = .stash(name: name, edge: edge)
        }
    }

    /// Encodes to the legacy SavedWindowActionFormat.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Encode the direction
        let direction = legacyExportDirection
        try container.encode(direction, forKey: .direction)

        // Encode additional properties based on action type
        switch self {
        case let .custom(custom):
            try container.encode(custom.name, forKey: .name)
            try container.encode(custom.unit, forKey: .unit)
            try container.encode(custom.anchor, forKey: .anchor)
            try container.encode(custom.sizeMode, forKey: .sizeMode)
            try container.encodeIfPresent(custom.width, forKey: .width)
            try container.encodeIfPresent(custom.height, forKey: .height)
            try container.encode(custom.positionMode, forKey: .positionMode)
            try container.encodeIfPresent(custom.xPoint, forKey: .xPoint)
            try container.encodeIfPresent(custom.yPoint, forKey: .yPoint)

        case let .cycle(actions):
            try container.encode(actions, forKey: .cycle)

        case let .stash(name, edge):
            try container.encode(name, forKey: .name)
            try container.encode(edge, forKey: .stashEdge)

        default:
            // Other action types don't need additional properties in the encoded format
            break
        }
    }

    /// Maps this action to its legacy WindowDirection equivalent for export compatibility.
    var legacyExportDirection: WindowDirection {
        switch self {
        case .special(.noAction): .noAction
        case .special(.noSelection): .noSelection
        case .special(.undo): .undo
        case .special(.initialFrame): .initialFrame
        case .special(.hide): .hide
        case .special(.minimize): .minimize
        case .special(.minimizeOthers): .minimizeOthers
        case let .standard(.proportional(layout)):
            layout.legacyDirection
        case .standard(.maximize): .maximize
        case .standard(.almostMaximize): .almostMaximize
        case .standard(.fullscreen): .fullscreen
        case .standard(.maximizeHeight): .maximizeHeight
        case .standard(.maximizeWidth): .maximizeWidth
        case .standard(.fillAvailableSpace): .fillAvailableSpace
        case .standard(.center(.geometric)): .center
        case .standard(.center(.macOS)): .macOSCenter
        case .incremental(.larger): .larger
        case .incremental(.smaller): .smaller
        case .incremental(.scaleUp): .scaleUp
        case .incremental(.scaleDown): .scaleDown
        case .incremental(.moveUp): .moveUp
        case .incremental(.moveDown): .moveDown
        case .incremental(.moveLeft): .moveLeft
        case .incremental(.moveRight): .moveRight
        case .incremental(.growTop): .growTop
        case .incremental(.growBottom): .growBottom
        case .incremental(.growLeft): .growLeft
        case .incremental(.growRight): .growRight
        case .incremental(.growHorizontal): .growHorizontal
        case .incremental(.growVertical): .growVertical
        case .incremental(.shrinkTop): .shrinkTop
        case .incremental(.shrinkBottom): .shrinkBottom
        case .incremental(.shrinkLeft): .shrinkLeft
        case .incremental(.shrinkRight): .shrinkRight
        case .incremental(.shrinkHorizontal): .shrinkHorizontal
        case .incremental(.shrinkVertical): .shrinkVertical
        case .focus(.focusUp): .focusUp
        case .focus(.focusDown): .focusDown
        case .focus(.focusLeft): .focusLeft
        case .focus(.focusRight): .focusRight
        case .focus(.focusNextInStack): .focusNextInStack
        case .screen(.next): .nextScreen
        case .screen(.previous): .previousScreen
        case .screen(.left): .leftScreen
        case .screen(.right): .rightScreen
        case .screen(.top): .topScreen
        case .screen(.bottom): .bottomScreen
        case .custom: .custom
        case .cycle: .cycle
        case .stash: .stash
        }
    }
}

// MARK: - ProportionalLayout Legacy Direction Mapping (for Codable)

private extension ProportionalLayout {
    var legacyDirection: WindowDirection {
        switch self {
        case .topHalf: .topHalf
        case .rightHalf: .rightHalf
        case .bottomHalf: .bottomHalf
        case .leftHalf: .leftHalf
        case .horizontalCenterHalf: .horizontalCenterHalf
        case .verticalCenterHalf: .verticalCenterHalf
        case .topLeftQuarter: .topLeftQuarter
        case .topRightQuarter: .topRightQuarter
        case .bottomRightQuarter: .bottomRightQuarter
        case .bottomLeftQuarter: .bottomLeftQuarter
        case .rightThird: .rightThird
        case .rightTwoThirds: .rightTwoThirds
        case .horizontalCenterThird: .horizontalCenterThird
        case .leftThird: .leftThird
        case .leftTwoThirds: .leftTwoThirds
        case .topThird: .topThird
        case .topTwoThirds: .topTwoThirds
        case .verticalCenterThird: .verticalCenterThird
        case .bottomThird: .bottomThird
        case .bottomTwoThirds: .bottomTwoThirds
        case .firstFourth: .firstFourth
        case .secondFourth: .secondFourth
        case .thirdFourth: .thirdFourth
        case .fourthFourth: .fourthFourth
        case .leftThreeFourths: .leftThreeFourths
        case .rightThreeFourths: .rightThreeFourths
        default:
            // Fallback for unknown layouts (shouldn't happen with predefined constants)
            .custom
        }
    }
}
