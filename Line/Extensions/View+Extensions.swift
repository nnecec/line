//
//  View+Extensions.swift
//  Line
//
//  Created by nnecec on 2023-06-14.
//

import SwiftUI

extension View {
    @inlinable
    @ViewBuilder
    func onChange(
        of value: some Equatable,
        initial: Bool,
        action: @escaping () -> ()
    ) -> some View {
        if initial {
            onChange(of: value) { _, _ in
                action()
            }
            .onAppear {
                action()
            }
        } else {
            onChange(of: value) { _, _ in
                action()
            }
        }
    }
}
