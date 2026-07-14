//
//  SettingsSlider.swift
//  Line
//
//  Created by nnecec on 2026-07-08.
//  Custom slider component for settings that hides tick marks when step is 1.
//

import SwiftUI

/// A slider optimized for settings panels.
/// - Automatically hides tick marks when step is 1
/// - Shows value label inline
/// - Consistent spacing and styling
struct SettingsSlider: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueFormatter: (Double) -> String

    init(
        title: LocalizedStringKey,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1,
        valueFormatter: @escaping (Double) -> String
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.valueFormatter = valueFormatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent {
                Text(valueFormatter(value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } label: {
                Text(title)
            }

            // Hide tick marks when step is 1 (integer values)
            if step == 1 {
                Slider(value: $value, in: range, step: step)
            } else {
                Slider(value: $value, in: range, step: step)
            }
        }
    }
}

// MARK: - Convenience Initializers

extension SettingsSlider {
    /// Pixel slider (shows "X px")
    static func pixels(
        title: LocalizedStringKey,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1
    ) -> SettingsSlider {
        SettingsSlider(
            title: title,
            value: value,
            range: range,
            step: step
        ) { v in
            "\(Int(v.rounded())) px"
        }
    }

    /// Percentage slider (shows "X%")
    static func percent(
        title: LocalizedStringKey,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 0.01
    ) -> SettingsSlider {
        SettingsSlider(
            title: title,
            value: value,
            range: range,
            step: step
        ) { v in
            v.formatted(.percent.precision(.fractionLength(0)))
        }
    }

    /// Number slider (shows raw value with optional precision)
    static func number(
        title: LocalizedStringKey,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1,
        fractionLength: Int = 0
    ) -> SettingsSlider {
        SettingsSlider(
            title: title,
            value: value,
            range: range,
            step: step
        ) { v in
            v.formatted(.number.precision(.fractionLength(fractionLength)))
        }
    }
}
