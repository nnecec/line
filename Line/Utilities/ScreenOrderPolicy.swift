//
//  ScreenOrderPolicy.swift
//  Line
//

import CoreGraphics

/// Orders display frames in the same positional order used by screen cycling.
enum ScreenOrderPolicy {
    static func ordered<Item>(
        _ items: [Item],
        frame: (Item) -> CGRect
    ) -> [Item] {
        items.sorted { first, second in
            let firstFrame = frame(first)
            let secondFrame = frame(second)

            if secondFrame.maxY <= firstFrame.minY {
                return true
            }

            if firstFrame.maxY <= secondFrame.minY {
                return false
            }

            return firstFrame.minX < secondFrame.minX
        }
    }
}
