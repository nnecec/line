//
//  CGEvent+Extensions.swift
//  Line
//
//  Created by nnecec on 2023-12-23.
//

import Cocoa

extension CGEvent {
    static var mouseLocation: CGPoint? {
        CGEvent(source: nil)?.location
    }
}
