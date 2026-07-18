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
                        Text("Done", comment: "Label for a button that dismisses a settings sheet")
                    }
                    .keyboardShortcut(.defaultAction)
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
        SettingsSlider.pixels(
            title: "Padding",
            value: uniformPaddingBinding,
            range: range,
            showsTextField: true,
            clampsUpper: false,
            onEditingChanged: handleSliderEditingChanged
        )
    }

    @ViewBuilder
    private func screenSidesPaddingConfiguration() -> some View {
        SettingsSlider.pixels(
            title: "Top",
            value: $paddingModel.top.doubleBinding,
            range: range,
            showsTextField: true,
            clampsUpper: false,
            onEditingChanged: handleSliderEditingChanged
        )

        SettingsSlider.pixels(
            title: "Bottom",
            value: $paddingModel.bottom.doubleBinding,
            range: range,
            showsTextField: true,
            clampsUpper: false,
            onEditingChanged: handleSliderEditingChanged
        )

        SettingsSlider.pixels(
            title: "Right",
            value: $paddingModel.right.doubleBinding,
            range: range,
            showsTextField: true,
            clampsUpper: false,
            onEditingChanged: handleSliderEditingChanged
        )

        SettingsSlider.pixels(
            title: "Left",
            value: $paddingModel.left.doubleBinding,
            range: range,
            showsTextField: true,
            clampsUpper: false,
            onEditingChanged: handleSliderEditingChanged
        )
    }

    @ViewBuilder
    private func screenInsetsPaddingConfiguration() -> some View {
        SettingsSlider.pixels(
            title: "Window gaps",
            value: $paddingModel.window.doubleBinding,
            range: range,
            showsTextField: true,
            clampsUpper: false,
            onEditingChanged: handleSliderEditingChanged
        )

        SettingsSlider.pixels(
            title: "External bar",
            value: $paddingModel.externalBar.doubleBinding,
            range: range,
            showsTextField: true,
            clampsUpper: false,
            help: "Use this if you are using a custom menubar.",
            onEditingChanged: handleSliderEditingChanged
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
