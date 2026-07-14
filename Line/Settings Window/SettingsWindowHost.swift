//
//  SettingsWindowHost.swift
//  Line
//
//  Created by nnecec on 2024-05-28.
//

import AppKit
import Scribe

@Loggable
@MainActor
final class SettingsWindowHost {
    static let shared = SettingsWindowHost()

    private weak var state: SettingsState?
    private weak var settingsWindow: NSWindow?
    private var pendingTab: SettingsTab?
    private var hasPresentedSettingsWindow = false

    private init() {}

    func configure(state: SettingsState) {
        self.state = state

        if let pendingTab {
            state.currentTab = pendingTab
            self.pendingTab = nil
        }
    }

    func show(tab: SettingsTab? = nil) {
        prepare(tab: tab)

        guard let state else {
            log.warn("Settings state is not configured; deferring settings presentation")
            return
        }

        SettingsWindowController.show(state: state)
        finishShowing()
    }

    func settingsSceneWindowDidChange(_ window: NSWindow?) {
        settingsWindow = window
        if window != nil {
            hasPresentedSettingsWindow = true
        }
    }

    func settingsWindowDidClose() {
        guard hasPresentedSettingsWindow else { return }

        hasPresentedSettingsWindow = false
        log.info("Settings window closed")
        ApplicationPresentationController.shared.settingsWindowDidClose()
    }

    private func prepare(tab: SettingsTab?) {
        if let tab {
            if let state {
                state.currentTab = tab
            } else {
                pendingTab = tab
            }
        }

        ApplicationPresentationController.shared.prepareToPresentWindow()
    }

    private func finishShowing() {
        settingsWindow?.makeKeyAndOrderFront(nil)
        ApplicationPresentationController.shared.activate()

        log.info("Settings window opened")
    }
}
