//
//  PreviewConfiguration.swift
//  Line
//
//  Preview settings pane: Displays-style fixed live preview at the top,
//  with scrollable configuration for accent, glass, grid overlay, and
//  window destination-frame chrome.
//

import AppKit
import Defaults
import SwiftUI

private let gridOverlayMinimumOpacity = 0.16

@available(macOS 15.0, *)
struct PreviewConfigurationView: View {
    @ObservedObject private var accentColorController: AccentColorController = .shared

    // Accent Color
    @Default(.accentColorMode) private var accentColorMode
    @Default(.customAccentColor) private var customAccentColor

    // Glass Effect (shared across grid overlay + window preview)
    @Default(.previewBackgroundEnableBlur) private var glassEnabled
    @Default(.previewGlassStyle) private var glassStyle
    @Default(.gridOverlayBlurEnabled) private var gridGlassEnabled
    @Default(.gridGlassStyle) private var gridGlassStyle
    @Default(.previewBackgroundAccentOpacity) private var previewBackgroundAccentOpacity

    // Window Preview
    @Default(.previewVisibility) private var previewVisibility
    @Default(.moveCursorWithWindow) private var moveCursorWithWindow
    @Default(.previewPadding) private var previewPadding
    @Default(.previewCornerRadius) private var previewCornerRadius
    @Default(.previewBorderThickness) private var previewBorderThickness
    @Default(.previewBorderStyle) private var borderStyle
    @Default(.previewUseWindowCornerRadius) private var previewUseWindowCornerRadius

    // Grid Overlay
    @Default(.gridFollowsAppAccentColor) private var followsAppAccent
    @Default(.gridOverlayAccentColor) private var gridAccentColor
    @Default(.gridOverlayOpacity) private var overlayOpacity
    @Default(.gridLineThickness) private var lineThickness
    @Default(.gridCellCornerRadius) private var cornerRadius
    @Default(.gridOverlayDrawStyle) private var drawStyle
    @Default(.gridSelectionGlow) private var selectionGlow
    @Default(.gridOverlayOuterCornerRadius) private var outerCornerRadius
    @Default(.defaultGridTemplate) private var defaultTemplate

    @State private var didSyncWallpaper: Bool = false
    @State private var syncWallpaperTask: Task<(), Never>?

    var body: some View {
        VStack(spacing: 0) {
            livePreviewHero
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 10)

            Form {
                accentColorSection
                glassEffectSection
                gridOverlaySection
                windowPreviewSection
            }
            .settingsFormPanel(maxWidth: 560)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Fixed Live Preview (side-by-side)

    private var livePreviewHero: some View {
        SettingsLivePreviewStage {
            HStack(alignment: .top, spacing: 16) {
                previewColumn(
                    title: String(
                        localized: "Grid Overlay",
                        comment: "Label above the grid overlay live preview"
                    )
                ) {
                    CompactGridPreview(
                        template: defaultTemplate,
                        accentColor: effectiveGridAccentColor,
                        showStyleChrome: true
                    )
                }

                previewColumn(
                    title: String(
                        localized: "Window Preview",
                        comment: "Label above the window preview live mock"
                    )
                ) {
                    CompactWindowPreview()
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(
                Text("Live preview", comment: "Accessibility label for the fixed preview hero")
            )
        }
        .accessibilityElement(children: .contain)
    }

    private func previewColumn<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            content()
                .frame(maxWidth: .infinity)
                .frame(height: 148)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Accent Color

    private var accentColorSection: some View {
        Section {
            Picker("Accent color", selection: $accentColorMode) {
                ForEach(AccentColorOption.allCases, id: \.self) { option in
                    Label {
                        Text(option.text)
                    } icon: {
                        option.image
                    }
                    .tag(option)
                }
            }
            .pickerStyle(.segmented)

            if accentColorMode == .wallpaper {
                syncWallpaperButton
            }

            if accentColorMode == .custom {
                ColorPicker("Accent color", selection: $customAccentColor, supportsOpacity: false)
            }

            HStack {
                Spacer()
                Button("Reset to Default") {
                    resetAccentColorDefaults()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        } header: {
            Text("Accent Color", comment: "Settings section header for accent color")
        } footer: {
            Text(
                "Default uses neutral liquid glass. System, Wallpaper, and Custom only tint edges and highlights - not solid color blocks.",
                comment: "Settings footer for accent color"
            )
        }
        .animation(.default, value: accentColorMode)
    }

    private var syncWallpaperButton: some View {
        Button(action: syncWallpaper) {
            HStack {
                Text("Sync Wallpaper")

                if didSyncWallpaper {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.green)
                        .bold()
                        .transition(.opacity.combined(with: .scale(scale: 0.25)))
                }
            }
        }
    }

    // MARK: - Glass Effect

    private var glassEffectSection: some View {
        Section {
            Toggle(isOn: glassEnabledBinding) {
                SettingsRowLabel(
                    "Enable Liquid Glass",
                    detail: "Use the native translucent material for both grid overlay and window preview.",
                    systemImage: "sparkles.rectangle.stack"
                )
            }

            if glassEnabled {
                Picker(selection: glassStyleBinding) {
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

                if glassStyle == .tinted, accentColorMode.usesAccentTint {
                    SettingsSlider.percent(
                        title: "Accent tint strength",
                        value: $previewBackgroundAccentOpacity.doubleBinding,
                        range: 0...0.12,
                        step: 0.01
                    )
                }
            }

            HStack {
                Spacer()
                Button("Reset to Default") {
                    resetGlassEffectDefaults()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        } header: {
            Text("Glass Effect", comment: "Settings section header for glass effect")
        } footer: {
            Text(
                "Glass effect is shared between grid overlay and window preview for a unified visual style.",
                comment: "Settings footer for glass effect"
            )
        }
    }

    // MARK: - Grid Overlay

    private var gridOverlaySection: some View {
        Section {
            Picker(selection: $drawStyle) {
                ForEach(GridOverlayDrawStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            } label: {
                SettingsRowLabel(
                    "Draw Style",
                    detail: drawStyle.detail,
                    systemImage: "square.grid.3x3"
                )
            }

            Toggle(isOn: $followsAppAccent) {
                SettingsRowLabel(
                    "Follow Accent Color",
                    detail: "Use the accent color configured above for grid highlights.",
                    systemImage: "paintpalette"
                )
            }

            if !followsAppAccent {
                ColorPicker("Grid accent color", selection: $gridAccentColor)
            }

            SettingsSlider.percent(
                title: "Opacity",
                value: overlayOpacityBinding,
                range: gridOverlayMinimumOpacity...1
            )

            SettingsSlider.pixels(
                title: drawStyle == .cells ? "Cell Border Thickness" : "Line Thickness",
                value: $lineThickness.doubleBinding,
                range: 0.5...3,
                step: 0.5
            )

            SettingsSlider.pixels(
                title: "Cell Corner Radius",
                value: $cornerRadius.doubleBinding,
                range: 0...20,
                step: 1
            )

            SettingsSlider.pixels(
                title: "Outer Corner Radius",
                value: $outerCornerRadius.doubleBinding,
                range: 0...28,
                step: 1
            )

            SettingsSlider.percent(
                title: "Selection Glow",
                value: $selectionGlow,
                range: 0...1
            )

            HStack {
                Spacer()
                Button("Reset to Default") {
                    resetGridOverlayDefaults()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        } header: {
            Text("Grid Overlay", comment: "Settings section header for grid overlay")
        } footer: {
            Text(
                "These settings control the visual appearance of the grid overlay shown when arranging windows. Layout templates are configured in Grid Layout.",
                comment: "Settings footer for grid overlay"
            )
        }
    }

    // MARK: - Window Preview

    private var windowPreviewSection: some View {
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

            if #unavailable(macOS 26) {
                SettingsSlider.pixels(
                    title: "Corner radius",
                    value: $previewCornerRadius.doubleBinding,
                    range: 0...25,
                    step: 1
                )
            }

            if #available(macOS 26, *) {
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

            HStack {
                Spacer()
                Button("Reset to Default") {
                    resetWindowPreviewDefaults()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        } header: {
            Text("Window Preview", comment: "Settings section header for window preview")
        } footer: {
            Text(
                "These settings control the preview frame shown when Line is about to move a window.",
                comment: "Settings footer for window preview"
            )
        }
    }

    // MARK: - Helpers

    private var effectiveGridAccentColor: Color {
        followsAppAccent ? accentColorController.color1 : gridAccentColor
    }

    private var overlayOpacityBinding: Binding<Double> {
        Binding {
            max(gridOverlayMinimumOpacity, overlayOpacity)
        } set: { newValue in
            overlayOpacity = max(gridOverlayMinimumOpacity, newValue)
        }
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

    private var glassEnabledBinding: Binding<Bool> {
        Binding {
            glassEnabled
        } set: { newValue in
            glassEnabled = newValue
            gridGlassEnabled = newValue
        }
    }

    private var glassStyleBinding: Binding<LiquidGlassStyle> {
        Binding {
            glassStyle
        } set: { newValue in
            glassStyle = newValue
            gridGlassStyle = newValue
        }
    }

    // MARK: - Reset Functions

    private func resetAccentColorDefaults() {
        accentColorMode = .default
        customAccentColor = .teal
    }

    private func resetGlassEffectDefaults() {
        glassEnabled = true
        gridGlassEnabled = true
        glassStyle = .regular
        gridGlassStyle = .regular
        previewBackgroundAccentOpacity = 0.06
    }

    private func resetGridOverlayDefaults() {
        drawStyle = .cells
        lineThickness = 1
        cornerRadius = 4
        outerCornerRadius = 12
        selectionGlow = 0.35
        overlayOpacity = 0.3
        followsAppAccent = true
    }

    private func resetWindowPreviewDefaults() {
        previewVisibility = true
        previewPadding = 10
        previewCornerRadius = 10
        previewBorderThickness = 1.0
        borderStyle = .hairline
        if #available(macOS 26, *) {
            previewUseWindowCornerRadius = true
        }
    }

    private func syncWallpaper() {
        if syncWallpaperTask != nil {
            return
        }

        syncWallpaperTask = Task {
            await accentColorController.refresh(ignoreThrottle: true)

            withAnimation(.easeInOut(duration: 0.5)) {
                didSyncWallpaper = true
            }

            try? await Task.sleep(for: .seconds(2))

            withAnimation(.easeInOut(duration: 0.5)) {
                didSyncWallpaper = false
            }

            syncWallpaperTask = nil
        }
    }
}
