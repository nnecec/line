//
//  PaddingConfigurationView.swift
//  Line
//
//  Created by nnecec on 2024-04-19.
//

import Defaults
import SwiftUI

struct PaddingConfigurationView: View {
    @Default(.enablePadding) private var enablePadding

    @State private var paddingModel = Defaults[.padding]
    @State private var isDeferringDefaultsCommit = false
    @Binding var isPresented: Bool

    private let range: ClosedRange<Double> = 0...100

    var body: some View {
        Form {
            Section {
                ScreenView {
                    PaddingPreview($paddingModel)
                }
                .disabled(!enablePadding)
            } header: {
                Text("Preview", comment: "Section header shown in settings")
            }

            Section {
                Toggle("Apply padding", isOn: $enablePadding)
            }

            Group {
                Section {
                    paddingMode()

                    if !paddingModel.configureScreenPadding {
                        nonScreenPaddingConfiguration()
                    } else {
                        screenSidesPaddingConfiguration()
                    }
                } header: {
                    Text("Padding", comment: "Section header shown in settings")
                }

                if paddingModel.configureScreenPadding {
                    Section {
                        screenInsetsPaddingConfiguration()
                    } header: {
                        Text("Screen Insets", comment: "Section header shown in settings")
                    }
                }
            }
            .disabled(!enablePadding)

            Section {
                HStack {
                    Spacer()

                    Button {
                        isPresented = false
                    } label: {
                        Text("Close", comment: "Label for a button that closes a modal window")
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: paddingModel) {
            guard !isDeferringDefaultsCommit else { return }
            // This fixes some weird animations.
            Defaults[.padding] = paddingModel
        }
    }

    private func paddingMode() -> some View {
        Picker("Mode", selection: configureScreenPaddingBinding) {
            Label("Simple", systemImage: "square")
                .tag(false)

            Label("Custom", systemImage: "slider.horizontal.3")
                .tag(true)
        }
        .pickerStyle(.segmented)
    }

    private func nonScreenPaddingConfiguration() -> some View {
        pixelSlider(
            Text("Padding"),
            value: uniformPaddingBinding,
            in: range,
            clampsUpper: false
        )
    }

    @ViewBuilder
    private func screenSidesPaddingConfiguration() -> some View {
        pixelSlider(
            Text("Top", comment: "Label for a slider in Line’s padding settings"),
            value: $paddingModel.top.doubleBinding,
            in: range,
            clampsUpper: false
        )

        pixelSlider(
            Text("Bottom", comment: "Label for a slider in Line’s padding settings"),
            value: $paddingModel.bottom.doubleBinding,
            in: range,
            clampsUpper: false
        )

        pixelSlider(
            Text("Right", comment: "Label for a slider in Line’s padding settings"),
            value: $paddingModel.right.doubleBinding,
            in: range,
            clampsUpper: false
        )

        pixelSlider(
            Text("Left", comment: "Label for a slider in Line’s padding settings"),
            value: $paddingModel.left.doubleBinding,
            in: range,
            clampsUpper: false
        )
    }

    @ViewBuilder
    private func screenInsetsPaddingConfiguration() -> some View {
        pixelSlider(
            Text("Window gaps", comment: "Label for a slider in Line’s padding settings"),
            value: $paddingModel.window.doubleBinding,
            in: range,
            clampsUpper: false
        )

        pixelSlider(
            Text("External bar", comment: "Label for a slider in Line’s padding settings"),
            value: $paddingModel.externalBar.doubleBinding,
            in: range,
            clampsUpper: false,
            help: "Use this if you are using a custom menubar."
        )
    }

    private var configureScreenPaddingBinding: Binding<Bool> {
        Binding {
            paddingModel.configureScreenPadding
        } set: { newValue in
            withAnimation(.default) {
                paddingModel.configureScreenPadding = newValue

                if !paddingModel.configureScreenPadding {
                    if paddingModel.allEqual {
                        let window = paddingModel.window
                        paddingModel.top = window
                        paddingModel.bottom = window
                        paddingModel.right = window
                        paddingModel.left = window
                    } else {
                        paddingModel.window = 0
                        paddingModel.top = 0
                        paddingModel.bottom = 0
                        paddingModel.right = 0
                        paddingModel.left = 0
                    }
                }
            }
        }
    }

    private var uniformPaddingBinding: Binding<Double> {
        Binding {
            Double(paddingModel.window)
        } set: { newValue in
            let padding = CGFloat(newValue)
            paddingModel.window = padding
            paddingModel.top = padding
            paddingModel.bottom = padding
            paddingModel.right = padding
            paddingModel.left = padding
        }
    }

    private func pixelSlider(
        _ title: Text,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double = 1,
        clampsUpper: Bool = true,
        help: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent {
                HStack(spacing: 4) {
                    TextField(
                        "Value",
                        value: numericBinding(value, in: range, clampsUpper: clampsUpper),
                        format: .number.precision(.fractionLength(0...1))
                    )
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 64)
                    .accessibilityLabel(title)

                    Text("px", comment: "Unit symbol: pixels")
                        .foregroundStyle(.secondary)
                }
            } label: {
                if let help {
                    title.help(help)
                } else {
                    title
                }
            }

            Slider(
                value: sliderBinding(value, in: range),
                in: range,
                step: step,
                onEditingChanged: handleSliderEditingChanged
            )
        }
    }

    private func numericBinding(
        _ value: Binding<Double>,
        in range: ClosedRange<Double>,
        clampsUpper: Bool
    ) -> Binding<Double> {
        Binding {
            value.wrappedValue
        } set: { newValue in
            let lowerClampedValue = max(range.lowerBound, newValue)
            value.wrappedValue = if clampsUpper {
                min(lowerClampedValue, range.upperBound)
            } else {
                lowerClampedValue
            }
        }
    }

    private func sliderBinding(
        _ value: Binding<Double>,
        in range: ClosedRange<Double>
    ) -> Binding<Double> {
        Binding {
            min(max(value.wrappedValue, range.lowerBound), range.upperBound)
        } set: { newValue in
            value.wrappedValue = min(max(newValue, range.lowerBound), range.upperBound)
        }
    }

    private func handleSliderEditingChanged(_ isEditing: Bool) {
        if isEditing {
            isDeferringDefaultsCommit = true
        } else {
            commitSliderChanges()
        }
    }

    private func commitSliderChanges() {
        isDeferringDefaultsCommit = false
        Defaults[.padding] = paddingModel
    }
}
