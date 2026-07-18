//
//  SettingsSlider.swift
//  Line
//
//  Created by nnecec on 2026-07-08.
//  Custom slider component for settings panels.
//

import SwiftUI

/// A slider optimized for settings panels.
/// - Shows an inline value label or optional text field
/// - Consistent spacing and monospaced digit styling
struct SettingsSlider: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unitLabel: LocalizedStringKey?
    let showsTextField: Bool
    let clampsUpper: Bool
    let help: LocalizedStringKey?
    let onEditingChanged: ((Bool) -> ())?
    let valueFormatter: (Double) -> String

    init(
        title: LocalizedStringKey,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1,
        unitLabel: LocalizedStringKey? = nil,
        showsTextField: Bool = false,
        clampsUpper: Bool = true,
        help: LocalizedStringKey? = nil,
        onEditingChanged: ((Bool) -> ())? = nil,
        valueFormatter: @escaping (Double) -> String
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.unitLabel = unitLabel
        self.showsTextField = showsTextField
        self.clampsUpper = clampsUpper
        self.help = help
        self.onEditingChanged = onEditingChanged
        self.valueFormatter = valueFormatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent {
                valueControl
            } label: {
                titleLabel
            }

            if let onEditingChanged {
                Slider(
                    value: sliderBinding,
                    in: range,
                    step: step,
                    onEditingChanged: onEditingChanged
                )
            } else {
                Slider(value: sliderBinding, in: range, step: step)
            }
        }
    }

    @ViewBuilder
    private var titleLabel: some View {
        if let help {
            Text(title)
                .help(help)
        } else {
            Text(title)
        }
    }

    @ViewBuilder
    private var valueControl: some View {
        if showsTextField {
            HStack(spacing: 4) {
                TextField(
                    "Value",
                    value: numericBinding,
                    format: .number.precision(.fractionLength(0...1))
                )
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 64)
                .accessibilityLabel(Text(title))

                if let unitLabel {
                    Text(unitLabel)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Text(valueFormatter(value))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private var numericBinding: Binding<Double> {
        Binding {
            value
        } set: { newValue in
            let lowerClamped = max(range.lowerBound, newValue)
            value = clampsUpper ? min(lowerClamped, range.upperBound) : lowerClamped
        }
    }

    private var sliderBinding: Binding<Double> {
        Binding {
            min(max(value, range.lowerBound), range.upperBound)
        } set: { newValue in
            value = min(max(newValue, range.lowerBound), range.upperBound)
        }
    }
}

// MARK: - Convenience Initializers

extension SettingsSlider {
    /// Pixel slider (shows "X px" or an editable field with px unit)
    static func pixels(
        title: LocalizedStringKey,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1,
        showsTextField: Bool = false,
        clampsUpper: Bool = true,
        help: LocalizedStringKey? = nil,
        onEditingChanged: ((Bool) -> ())? = nil
    ) -> SettingsSlider {
        SettingsSlider(
            title: title,
            value: value,
            range: range,
            step: step,
            unitLabel: showsTextField ? "px" : nil,
            showsTextField: showsTextField,
            clampsUpper: clampsUpper,
            help: help,
            onEditingChanged: onEditingChanged
        ) { v in
            "\(Int(v.rounded())) px"
        }
    }

    /// Percentage slider (shows "X%")
    static func percent(
        title: LocalizedStringKey,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 0.01,
        onEditingChanged: ((Bool) -> ())? = nil
    ) -> SettingsSlider {
        SettingsSlider(
            title: title,
            value: value,
            range: range,
            step: step,
            onEditingChanged: onEditingChanged
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
        fractionLength: Int = 0,
        onEditingChanged: ((Bool) -> ())? = nil
    ) -> SettingsSlider {
        SettingsSlider(
            title: title,
            value: value,
            range: range,
            step: step,
            onEditingChanged: onEditingChanged
        ) { v in
            v.formatted(.number.precision(.fractionLength(fractionLength)))
        }
    }
}
