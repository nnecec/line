//
//  SettingsSceneRoot.swift
//  Line
//
//  Created by nnecec on 2026-07-03.
//

import AppKit
import SwiftUI

struct SettingsSceneRoot: View {
    @ObservedObject var state: SettingsState
    @State private var currentWindow: NSWindow?

    var body: some View {
        SettingsContentView(state: state)
            .background(
                SettingsWindowReader { window in
                    currentWindow = window
                    SettingsWindowHost.shared.settingsSceneWindowDidChange(window)
                }
            )
            .environment(\.settingsWindowProvider, SettingsWindowProvider {
                currentWindow
            })
            .onDisappear {
                SettingsWindowHost.shared.settingsSceneWindowDidChange(nil)
                SettingsWindowHost.shared.settingsWindowDidClose()
            }
    }
}

private struct SettingsWindowReader: NSViewRepresentable {
    let onWindowChange: @MainActor (NSWindow?) -> ()

    func makeNSView(context _: Context) -> WindowReaderView {
        WindowReaderView(onWindowChange: onWindowChange)
    }

    func updateNSView(_ nsView: WindowReaderView, context _: Context) {
        nsView.onWindowChange = onWindowChange
        nsView.reportWindow()
    }

    final class WindowReaderView: NSView {
        var onWindowChange: @MainActor (NSWindow?) -> ()

        init(onWindowChange: @escaping @MainActor (NSWindow?) -> ()) {
            self.onWindowChange = onWindowChange
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            reportWindow()
        }

        func reportWindow() {
            onWindowChange(window)
        }
    }
}
