//
//  BehaviorConfiguration.swift
//  Line
//
//  Created by nnecec on 2024-04-19.
//

import Defaults
import SwiftUI

struct BehaviorConfigurationView: View {
    @Default(.launchAtLogin) var launchAtLogin
    @Default(.hideMenuBarIcon) var hideMenuBarIcon
    @Default(.showDockIcon) var showDockIcon
    @Default(.animationConfiguration) var animationConfiguration
    @Default(.windowSnapping) var windowSnapping
    @Default(.suppressMissionControlOnTopDrag) var suppressMissionControlOnTopDrag
    @Default(.restoreWindowFrameOnDrag) var restoreWindowFrameOnDrag
    @Default(.useSystemWindowManagerWhenAvailable) var useSystemWindowManagerWhenAvailable
    @Default(.useScreenWithCursor) var useScreenWithCursor
    @Default(.moveCursorWithWindow) var moveCursorWithWindow
    @Default(.resizeWindowUnderCursor) var resizeWindowUnderCursor
    @Default(.focusWindowOnResize) var focusWindowOnResize
    @Default(.respectStageManager) var respectStageManager
    @Default(.stageStripSize) var stageStripSize
    @Default(.previewVisibility) var previewVisibility
    @Default(.stashedWindowVisiblePadding) var stashedWindowVisiblePadding
    @Default(.animateStashedWindows) var animateStashedWindows
    @Default(.shiftFocusWhenStashed) var shiftFocusWhenStashed

    @State private var isPaddingConfigurationViewPresented = false

    var body: some View {
        Form {
            generalSection
            windowSection
            cursorSection
            windowSnappingSection
            stageManagerSection
            stashSection
        }
        .settingsFormPanel()
        .animation(
            .default,
            value: [
                previewVisibility,
                resizeWindowUnderCursor,
                windowSnapping,
                respectStageManager,
                useSystemWindowManagerWhenAvailable
            ]
        )
        .sheet(isPresented: $isPaddingConfigurationViewPresented) {
            PaddingConfigurationView(isPresented: $isPaddingConfigurationViewPresented)
                .frame(width: 400)
        }
    }

    private var generalSection: some View {
        Section {
            Toggle(isOn: $launchAtLogin) {
                SettingsRowLabel(
                    "Launch at login",
                    detail: "Start Line automatically when you sign in.",
                    systemImage: "power"
                )
            }

            Toggle(isOn: $hideMenuBarIcon) {
                SettingsRowLabel(
                    "Hide menu bar icon",
                    detail: "Run quietly without showing Line in the menu bar.",
                    systemImage: "menubar.rectangle"
                )
            }

            Toggle(isOn: $showDockIcon) {
                SettingsRowLabel(
                    "Show in Dock",
                    detail: "Switch Line from an accessory app to a regular Dock app.",
                    systemImage: "dock.rectangle"
                )
            }

            Picker("Animation speed", selection: $animationConfiguration) {
                ForEach(AnimationConfiguration.allCases.reversed()) { item in
                    Text(item.name)
                        .monospaced()
                        .tag(item)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("General", comment: "Section header shown in settings")
        }
    }

    private var windowSection: some View {
        Section {
            Toggle(isOn: $useScreenWithCursor) {
                SettingsRowLabel(
                    "Move window to cursor's screen",
                    detail: "Use the display under the pointer as the target display.",
                    systemImage: "cursorarrow.motionlines"
                )
            }

            // Enabling the system window manager will override these options.
            if !useSystemWindowManagerWhenAvailable {
                Toggle(isOn: $restoreWindowFrameOnDrag) {
                    SettingsRowLabel(
                        "Restore window frame on drag",
                        detail: "Return a resized window to its previous frame before dragging.",
                        systemImage: "arrow.uturn.backward.square"
                    )
                }

                LabeledContent("Padding") {
                    Button("Configure…") {
                        isPaddingConfigurationViewPresented = true
                    }
                    .keyboardShortcut(.defaultAction)
                    .help("Open padding configuration")
                }
            }
        } header: {
            Text("Window", comment: "Section header shown in settings")
        }
    }

    private var cursorSection: some View {
        Section {
            // This can only be enabled when the preview is visible.
            // Because when the preview is disabled, the window moves live with cursor movement,
            // so moving the cursor would be unusable.
            if previewVisibility {
                Toggle(isOn: $moveCursorWithWindow) {
                    SettingsRowLabel(
                        "Move cursor with window",
                        detail: "Keep the pointer near the arranged window after a move.",
                        systemImage: "cursorarrow"
                    )
                }
            }

            Toggle(isOn: $resizeWindowUnderCursor) {
                SettingsRowLabel(
                    "Resize window under cursor",
                    detail: "Target the window below the pointer instead of the frontmost window.",
                    systemImage: "rectangle.and.hand.point.up.left"
                )
            }

            // If the system WM is enabled, the window under the cursor requires focus.
            if resizeWindowUnderCursor, !useSystemWindowManagerWhenAvailable {
                Toggle(isOn: $focusWindowOnResize) {
                    SettingsRowLabel(
                        "Focus window on resize",
                        detail: "Bring the targeted window forward before applying the resize.",
                        systemImage: "scope"
                    )
                }
            }
        } header: {
            Text("Cursor", comment: "Section header shown in settings")
        }
    }

    private var windowSnappingSection: some View {
        Section {
            windowSnappingToggle

            if windowSnapping {
                Toggle(isOn: $suppressMissionControlOnTopDrag) {
                    SettingsRowLabel(
                        "Suppress Mission Control",
                        detail: "Prevent Mission Control from opening when a dragged window touches the top edge.",
                        systemImage: "rectangle.topthird.inset.filled"
                    )
                    .help("Whether to allow Mission Control to open when windows are dragged to the top of the screen.")
                }
            }
        } header: {
            Text("Window Snapping", comment: "Section header shown in settings")
        }
    }

    @ViewBuilder
    private var windowSnappingToggle: some View {
        if #available(macOS 15, *) {
            if SystemWindowManager.MoveAndResize.snappingEnabled {
                Toggle(isOn: $windowSnapping) {
                    SettingsRowLabel(
                        "Enable window snapping",
                        detail: "Snap windows to screen edges with Line. Disable macOS tiling first if the two conflict.",
                        systemImage: "rectangle.inset.filled.and.person.filled"
                    )
                    .help("macOS's \"Tile by dragging windows to screen edges\" feature is currently enabled, which will conflict with Line's window snapping functionality.")
                }
            } else {
                Toggle(isOn: $windowSnapping) {
                    SettingsRowLabel(
                        "Enable window snapping",
                        detail: "Snap windows to screen edges with Line.",
                        systemImage: "rectangle.inset.filled.and.person.filled"
                    )
                }
            }
        } else {
            Toggle(isOn: $windowSnapping) {
                SettingsRowLabel(
                    "Enable window snapping",
                    detail: "Snap windows to screen edges with Line.",
                    systemImage: "rectangle.inset.filled.and.person.filled"
                )
            }
        }
    }

    private var stageManagerSection: some View {
        Section {
            Toggle(isOn: $respectStageManager) {
                SettingsRowLabel(
                    "Respect Stage Manager",
                    detail: "Keep arranged windows clear of the Stage Manager strip.",
                    systemImage: "rectangle.3.group"
                )
            }

            if respectStageManager {
                SettingsSlider.pixels(
                    title: "Stage strip size",
                    value: $stageStripSize.doubleBinding,
                    range: 50...250,
                    step: 1
                )
            }
        } header: {
            Text("Stage Manager", comment: "Section header shown in settings")
        }
    }

    private var stashSection: some View {
        Section {
            Toggle(isOn: $animateStashedWindows) {
                SettingsRowLabel(
                    "Animate stashed windows",
                    detail: "Use motion when hiding and restoring stashed windows.",
                    systemImage: "rectangle.compress.vertical"
                )
            }

            SettingsSlider.pixels(
                title: "Peek size",
                value: $stashedWindowVisiblePadding.doubleBinding,
                range: 1...100,
                step: 1
            )

            Toggle(isOn: $shiftFocusWhenStashed) {
                SettingsRowLabel(
                    "Shift focus when stashed",
                    detail: "Move focus away after the active window is stashed.",
                    systemImage: "arrowshape.turn.up.right"
                )
            }
        } header: {
            Text("Stash", comment: "Section header shown in settings")
        }
        .onChange(of: stashedWindowVisiblePadding) {
            Task { await StashManager.shared.onConfigurationChanged() }
        }
    }
}

