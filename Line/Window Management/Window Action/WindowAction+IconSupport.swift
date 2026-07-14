//
//  WindowAction+IconSupport.swift
//  Line
//
//  Created via architecture refactor on 2026-07-02.
//
//  Icon support for WindowAction - provides image, semanticKey, and iconResolvedAction
//  for UI components like IconView.
//

import Foundation
import SwiftUI

// MARK: - WindowActionImage

enum WindowActionImage {
    case systemImage(String)
    case resource(ImageResource)

    var image: Image {
        switch self {
        case let .systemImage(string):
            Image(systemName: string)
        case let .resource(resource):
            Image(resource)
        }
    }

    var nsImage: NSImage {
        switch self {
        case let .systemImage(string):
            let image = NSImage(systemSymbolName: string, accessibilityDescription: nil)
            return image?.withSymbolConfiguration(.init(pointSize: 20, weight: .bold)) ?? image ?? NSImage()
        case let .resource(resource):
            return NSImage(resource: resource)
        }
    }
}

// MARK: - SemanticKey

extension WindowAction {
    /// A semantic identifier used for icon caching and comparison.
    /// Actions with the same semantic meaning share the same key.
    struct SemanticKey: Hashable {
        private let value: String

        init(_ value: String) {
            self.value = value
        }
    }

    var semanticKey: SemanticKey {
        // For cycles, use the first action's semantic key
        if case let .cycle(actions) = self, let first = actions.first {
            return first.semanticKey
        }

        // Generate a stable string representation
        return SemanticKey(String(describing: self))
    }
}

// MARK: - Icon Resolution

extension WindowAction {
    /// Returns the action that should be used for icon display.
    /// For cycle actions, returns the first action in the cycle.
    var iconResolvedAction: WindowAction {
        if case let .cycle(actions) = self, let first = actions.first {
            return first.iconResolvedAction
        }
        return self
    }

    /// Returns the image to display for this action, if available.
    var image: WindowActionImage? {
        switch self {
        // Special actions with images
        case .special(.noAction):
            .systemImage("questionmark")
        case .special(.undo):
            .systemImage("arrow.uturn.backward")
        case .special(.initialFrame):
            .systemImage("backward.end.fill")
        case .special(.hide):
            .systemImage("eye.slash")
        case .special(.minimize):
            .systemImage("arrow.down.right.and.arrow.up.left")
        case .special(.minimizeOthers):
            .systemImage("arrow.down.right.and.arrow.up.left")
        // Standard actions with images
        case .standard(.maximizeHeight):
            .systemImage("arrow.up.and.down")
        case .standard(.maximizeWidth):
            .systemImage("arrow.left.and.right")
        case .standard(.fillAvailableSpace):
            .systemImage("arrow.up.left.and.arrow.down.right")
        // Screen switching
        case .screen(.next):
            .systemImage("arrow.forward")
        case .screen(.previous):
            .systemImage("arrow.backward")
        case .screen(.left):
            .systemImage("arrow.left.to.line")
        case .screen(.right):
            .systemImage("arrow.right.to.line")
        case .screen(.top):
            .systemImage("arrow.up.to.line")
        case .screen(.bottom):
            .systemImage("arrow.down.to.line")
        // Incremental actions
        case .incremental(.larger), .incremental(.scaleUp):
            .systemImage("arrow.up.left.and.arrow.down.right")
        case .incremental(.smaller), .incremental(.scaleDown):
            .systemImage("arrow.down.right.and.arrow.up.left")
        case .incremental(.shrinkTop), .incremental(.growBottom), .incremental(.moveDown):
            .systemImage("arrow.down")
        case .incremental(.shrinkBottom), .incremental(.growTop), .incremental(.moveUp):
            .systemImage("arrow.up")
        case .incremental(.shrinkRight), .incremental(.growLeft), .incremental(.moveLeft):
            .systemImage("arrow.left")
        case .incremental(.shrinkLeft), .incremental(.growRight), .incremental(.moveRight):
            .systemImage("arrow.right")
        case .incremental(.shrinkHorizontal):
            .systemImage("arrow.right.and.line.vertical.and.arrow.left")
        case .incremental(.growHorizontal):
            .systemImage("arrow.left.and.line.vertical.and.arrow.right")
        case .incremental(.shrinkVertical):
            .systemImage("arrow.down.and.line.horizontal.and.arrow.up")
        case .incremental(.growVertical):
            .systemImage("arrow.up.and.line.horizontal.and.arrow.down")
        // Focus actions
        case .focus(.focusLeft):
            .systemImage("chevron.left")
        case .focus(.focusRight):
            .systemImage("chevron.right")
        case .focus(.focusUp):
            .systemImage("chevron.up")
        case .focus(.focusDown):
            .systemImage("chevron.down")
        case .focus(.focusNextInStack):
            .systemImage("rectangle.stack")
        // No image for these - they'll use frame preview
        case .standard(.proportional), .standard(.maximize), .standard(.almostMaximize),
             .standard(.fullscreen), .standard(.center):
            nil
        // These get backup images
        case .custom, .cycle, .stash:
            nil
        case .special(.noSelection):
            nil
        }
    }

    /// Backup image when no primary image or frame is available.
    var backupImage: WindowActionImage? {
        switch self {
        case .custom:
            .systemImage("slider.horizontal.3")
        case .cycle:
            .systemImage("repeat")
        case .stash:
            .systemImage("archivebox.fill")
        default:
            nil
        }
    }
}

// MARK: - WindowDirection Conversion

extension WindowAction {
    /// Initialize a WindowAction from a legacy WindowDirection.
    /// Used for backward compatibility with IconView and other components.
    init(_ direction: WindowDirection) {
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
        // Standard - maximize variants
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
        // Standard - center
        case .center:
            self = .standard(.center(.geometric))
        case .macOSCenter:
            self = .standard(.center(.macOS))
        // Standard - halves
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
        // Standard - quarters
        case .topLeftQuarter:
            self = .standard(.proportional(.topLeftQuarter))
        case .topRightQuarter:
            self = .standard(.proportional(.topRightQuarter))
        case .bottomRightQuarter:
            self = .standard(.proportional(.bottomRightQuarter))
        case .bottomLeftQuarter:
            self = .standard(.proportional(.bottomLeftQuarter))
        // Standard - horizontal thirds
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
        // Standard - horizontal fourths
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
        // Standard - vertical thirds
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
        // Screen switching
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
        case .focusLeft:
            self = .focus(.focusLeft)
        case .focusRight:
            self = .focus(.focusRight)
        case .focusUp:
            self = .focus(.focusUp)
        case .focusDown:
            self = .focus(.focusDown)
        case .focusNextInStack:
            self = .focus(.focusNextInStack)
        // Stash
        case .stash:
            self = .stash(name: "Stash", edge: .left)
        // Any other cases that might exist
        default:
            self = .special(.noAction)
        }
    }

    /// Convert to WindowDirection for backward compatibility
    var toDirection: WindowDirection? {
        switch self {
        case .special(.noAction):
            .noAction
        case .special(.noSelection):
            .noSelection
        case .special(.undo):
            .undo
        case .special(.initialFrame):
            .initialFrame
        case .special(.hide):
            .hide
        case .special(.minimize):
            .minimize
        case .special(.minimizeOthers):
            .minimizeOthers
        case .standard(.maximize):
            .maximize
        case .standard(.almostMaximize):
            .almostMaximize
        case .standard(.fullscreen):
            .fullscreen
        case .standard(.maximizeHeight):
            .maximizeHeight
        case .standard(.maximizeWidth):
            .maximizeWidth
        case .standard(.fillAvailableSpace):
            .fillAvailableSpace
        case .standard(.center(.geometric)):
            .center
        case .standard(.center(.macOS)):
            .macOSCenter
        case .standard(.proportional(.topHalf)):
            .topHalf
        case .standard(.proportional(.rightHalf)):
            .rightHalf
        case .standard(.proportional(.bottomHalf)):
            .bottomHalf
        case .standard(.proportional(.leftHalf)):
            .leftHalf
        case .screen(.next):
            .nextScreen
        case .screen(.previous):
            .previousScreen
        case .incremental(.larger):
            .larger
        case .incremental(.smaller):
            .smaller
        default:
            nil
        }
    }

    /// Compatibility property for old code using .direction
    var direction: WindowDirection {
        toDirection ?? .noAction
    }

    /// Compatibility method for getName()
    func getName() -> String {
        if let direction = toDirection {
            return direction.rawValue
        }
        return "UnknownAction"
    }

    /// Check if this action will manipulate existing window frame
    var willManipulateExistingWindowFrame: Bool {
        if case .incremental = self {
            return true
        }
        return false
    }

    /// Check if this is a grid layout action
    var isGridLayoutAction: Bool {
        if case let .custom(custom) = self {
            return custom.name == "autogenerated_grid_layout" ||
                custom.name.hasPrefix("autogenerated_record_")
        }
        return false
    }
}
