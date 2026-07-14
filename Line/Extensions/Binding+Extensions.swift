//
//  Binding+Extensions.swift
//  Line
//
//  Created by nnecec on 2025-10-18.
//

import SwiftUI

extension Binding where Value == CGFloat {
    var doubleBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(wrappedValue) },
            set: { wrappedValue = CGFloat($0) }
        )
    }
}
