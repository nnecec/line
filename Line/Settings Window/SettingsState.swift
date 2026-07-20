//
//  SettingsState.swift
//  Line
//
//  Created by nnecec on 2026-07-03.
//

import Defaults
import SwiftUI

@MainActor
final class SettingsState: ObservableObject {
    @Published var isPreviewingUserSelection = false

    @Published private(set) var previewedParentAction: BoundWindowAction? = nil
    @Published private(set) var previewedAction = BoundWindowAction(action: .special(.noSelection), keybind: [])

    @Published var currentTab: SettingsTab = .preview

    init() {
        if let firstAction = Defaults[.keybinds].first {
            setPreviewedAction(to: firstAction)
        }
    }

    func setPreviewedAction(to newAction: BoundWindowAction, cycleAction: BoundWindowAction? = nil) {
        if case let .cycle(actions) = newAction.action {
            previewedParentAction = newAction
            if let cycleAction {
                previewedAction = cycleAction
            } else if let firstCycleAction = actions.first {
                previewedAction = BoundWindowAction(action: firstCycleAction, keybind: [])
            } else {
                previewedAction = BoundWindowAction(action: .special(.noAction), keybind: [])
            }
        } else {
            previewedParentAction = nil
            previewedAction = newAction
        }
    }
}
