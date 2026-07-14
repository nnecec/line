//
//  ApplicationPresentationController.swift
//  Line
//
//  Created by nnecec on 2026-07-03.
//

import AppKit
import Defaults

@MainActor
final class ApplicationPresentationController {
    static let shared = ApplicationPresentationController()

    private init() {}

    func prepareToPresentWindow() {
        NSApp.setActivationPolicy(.regular)
    }

    func activate() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func settingsWindowDidClose() {
        applyPreferredBackgroundPresentation()
    }

    func applyPreferredBackgroundPresentation() {
        if Defaults[.showDockIcon] {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
