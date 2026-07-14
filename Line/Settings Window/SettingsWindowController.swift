//
//  SettingsWindowController.swift
//  Line
//
//  Created by nnecec on 2026-07-08.
//  Native NSWindowController for liquid glass settings window with resizable frame.
//

import AppKit
import SwiftUI

/// Native window controller for the settings window.
/// Uses NSWindowController instead of SwiftUI Window scene to enable liquid glass chrome.
@MainActor
final class SettingsWindowController: NSWindowController {
    private static var shared: SettingsWindowController?
    private let state: SettingsState

    private init(state: SettingsState) {
        self.state = state

        let initialRect = NSRect(x: 0, y: 0, width: 900, height: 600)
        let styleMask: NSWindow.StyleMask = [
            .titled,
            .closable,
            .miniaturizable,
            .resizable,
            .fullSizeContentView
        ]

        let window = NSWindow(
            contentRect: initialRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        window.title = String(localized: "Line Settings", comment: "Window title for Line settings")
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.minSize = NSSize(width: 720, height: 520)
        window.setFrameAutosaveName("LineSettingsWindowV2")
        window.center()

        let rootView = SettingsSceneRoot(state: state)
        window.contentView = NSHostingView(rootView: rootView)

        window.isReleasedWhenClosed = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Show the settings window using the app-owned settings state.
    static func show(state: SettingsState) {
        if let existing = shared {
            existing.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = SettingsWindowController(state: state)
        shared = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}
