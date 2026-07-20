//
//  PreviewConfiguration.swift
//  Line
//
//  Created by nnecec on 2024-04-19.
//

import Defaults
import SwiftUI

struct PreviewConfigurationView: View {
    @Default(.previewVisibility) private var previewVisibility
    @Default(.moveCursorWithWindow) private var moveCursorWithWindow
    @Default(.previewPadding) private var previewPadding
    @Default(.previewCornerRadius) private var previewCornerRadius
    @Default(.previewBorderThickness) private var previewBorderThickness
    @Default(.previewBorderStyle) private var borderStyle
    @Default(.previewUseWindowCornerRadius) private var previewUseWindowCornerRadius
    @Default(.previewBackgroundEnableBlur) private var previewBackgroundEnableBlur
    @Default(.previewBackgroundAccentOpacity) private var previewBackgroundAccentOpacity
    @Default(.previewGlassStyle) private var glassStyle

    var body: some View {
        Form {
            Section {
                CompactWindowPreview()
                    .frame(height: 150)
                    .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
            } header: {
                Text("Live Preview", comment: "Settings section header for live window preview mock")
            } footer: {
                Text("Updates as you change padding, border, and glass options below.", comment: "Settings footer for live window preview mock")
            }

            Section {
                Toggle(isOn: previewVisibilityBinding) {
                    SettingsRowLabel(
                        "Show preview while arranging windows",
                        detail: "Show the destination frame before Line moves the window.",
                        systemImage: "rectangle.dashed"
                    )
                }

                SettingsSlider.pixels(
                    title: "Padding",
                    value: $previewPadding.doubleBinding,
                    range: 0...20,
                    step: 1
                )

                // On macOS Sequoia and below, simply show the corner radius slider.
                if #unavailable(macOS 26) {
                    SettingsSlider.pixels(
                        title: "Corner radius",
                        value: $previewCornerRadius.doubleBinding,
                        range: 0...25,
                        step: 1
                    )
                }

                Picker(selection: $borderStyle) {
                    ForEach(PreviewBorderStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                } label: {
                    SettingsRowLabel(
                        "Border Style",
                        detail: borderStyle.detail,
                        systemImage: "rectangle.dashed.badge.record"
                    )
                }

                if borderStyle.usesThickness {
                    SettingsSlider.pixels(
                        title: "Border thickness",
                        value: $previewBorderThickness.doubleBinding,
                        range: 0...2.5,
                        step: 0.5
                    )
                }
            }

            // On macOS Tahoe and above, Line can read the selected window’s corner radius.
            // So display it in a separate section, with the option to configure this functionality.
            if #available(macOS 26, *) {
                Section("Corner Radius") {
                    Toggle(isOn: $previewUseWindowCornerRadius) {
                        SettingsRowLabel(
                            "Use selected window corner radius",
                            detail: "Match the preview shape to the window being arranged when macOS exposes that value.",
                            systemImage: "rectangle.roundedtop"
                        )
                    }

                    SettingsSlider.pixels(
                        title: previewUseWindowCornerRadius ? "Default corner radius" : "Corner radius",
                        value: $previewCornerRadius.doubleBinding,
                        range: 0...25,
                        step: 1
                    )
                }
            }

            Section("Background") {
                Toggle(isOn: $previewBackgroundEnableBlur) {
                    SettingsRowLabel(
                        "Enable Liquid Glass",
                        detail: "Use the native translucent material for previews when transparency is allowed.",
                        systemImage: "sparkles.rectangle.stack"
                    )
                }

                if previewBackgroundEnableBlur {
                    Picker(selection: $glassStyle) {
                        ForEach(LiquidGlassStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    } label: {
                        SettingsRowLabel(
                            "Glass Style",
                            detail: glassStyle.detail,
                            systemImage: "rectangle.on.rectangle.angled"
                        )
                    }

                    if glassStyle == .tinted {
                        SettingsSlider.percent(
                            title: "Glass tint",
                            value: $previewBackgroundAccentOpacity.doubleBinding,
                            range: 0...0.25,
                            step: 0.01
                        )
                    }
                }
            }
        }
        .settingsFormPanel()
    }

    private var previewVisibilityBinding: Binding<Bool> {
        Binding {
            previewVisibility
        } set: { newValue in
            previewVisibility = newValue

            if !newValue {
                moveCursorWithWindow = false
            }
        }
    }
}
