//
//  StashActionConfigurationView.swift
//  Line
//
//  Created by Guillaume Clédat on 19/06/2025.
//

import Defaults
import Foundation
import SwiftUI

struct StashActionConfigurationView: View {
    @Binding var windowAction: WindowAction
    @Binding var isPresented: Bool

    @State private var action: WindowAction
    @State private var currentTab: Tab = .position
    @State private var isDeferringExternalCommit = false

    private enum Tab: LocalizedStringKey, CaseIterable {
        case position = "Position", size = "Unstashed Size"

        var image: Image {
            switch self {
            case .position:
                Image(systemName: "viewfinder")
            case .size:
                Image(systemName: "rectangle.expand.diagonal")
            }
        }
    }

    private let defaultAnchor: CustomWindowActionAnchor = .topLeft

    private var anchors: [CustomWindowActionAnchor] {
        [.topLeft, .none, .topRight,
         .left, .none, .right,
         .bottomLeft, .bottom, .bottomRight]
    }

    private var sizeModes: [CustomWindowActionSizeMode] {
        [.custom, .preserveSize]
    }

    private var stashName: String {
        if case let .stash(name, _) = action {
            return name
        }
        return ""
    }

    private var stashEdge: StashEdge {
        if case let .stash(_, edge) = action {
            return edge
        }
        return .left
    }

    private var actionUnit: CustomWindowActionUnit {
        .percentage // Stash actions always use percentage
    }

    private let previewController = PreviewController()
    private let screenSize: CGSize = NSScreen.main?.frame.size ?? NSScreen.screens[0].frame.size

    init(action: Binding<WindowAction>, isPresented: Binding<Bool>) {
        _windowAction = action
        _isPresented = isPresented
        _action = State(initialValue: action.wrappedValue)
    }

    var body: some View {
        Form {
            Section {
                ScreenView(isBlurred: true) {
                    ActionPreview(action: action)
                }
            }

            configurationSections()
            actionButtons()
        }
        .onChange(of: action) {
            guard !isDeferringExternalCommit else { return }
            windowAction = action
        }
    }

    @ViewBuilder
    private func configurationSections() -> some View {
        Section {
            TextField("Stash", text: Binding(
                get: { stashName },
                set: { newName in
                    action = .stash(name: newName, edge: stashEdge)
                }
            ))
            .textFieldStyle(.roundedBorder)
        }

        Section {
            tabPicker()
        }

        Section {
            if currentTab == .position {
                positionConfiguration()
            } else {
                sizeConfiguration()
            }
        }
        .animation(keybindConfigurationAnimation, value: actionUnit)
    }

    private func tabPicker() -> some View {
        Picker("Configuration", selection: $currentTab.animation(keybindConfigurationAnimation)) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Label {
                    Text(tab.rawValue)
                } icon: {
                    tab.image
                }
                .tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    private func actionButtons() -> some View {
        Section {
            HStack(spacing: 8) {
                Button("Preview") {}
                    .onLongPressGesture(
                        // Allows for a press-and-hold gesture to show the preview
                        minimumDuration: 100.0,
                        maximumDistance: .infinity,
                        pressing: { pressing in
                            if pressing {
                                guard let screen = NSScreen.main else { return }
                                let context = ResizeContext(screen: screen)
                                context.setAction(to: BoundWindowAction(action: action, keybind: []), parent: nil)
                                previewController.open(context: context)
                            } else {
                                previewController.close()
                            }
                        },
                        perform: {}
                    )
                    .disabled(true)

                Button {
                    isPresented = false
                } label: {
                    Text("Close", comment: "Label for a button that closes a modal window")
                }
                .keyboardShortcut(.cancelAction)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .buttonStyle(.bordered)
        }
    }

    private func positionConfiguration() -> some View {
        KeybindOptionGrid(
            elements: anchors,
            selection: .constant(defaultAnchor),
            columns: 3,
            isSelectable: \.isSelectable
        ) { anchor in
            if let iconAction = anchor.iconAction {
                IconView(action: iconAction)
            } else {
                Color.clear
            }
        }
        .disabled(true)
        .opacity(0.5)
    }

    private func sizeConfiguration() -> some View {
        KeybindOptionGrid(
            elements: sizeModes,
            selection: .constant(.preserveSize),
            columns: 2
        ) { mode in
            VStack(spacing: 4) {
                mode.image
                Text(mode.name)
            }
            .padding(.vertical, 15)
            .compositingGroup()
        }
        .disabled(true)
        .opacity(0.5)
    }

    private func handleSliderEditingChanged(_ isEditing: Bool) {
        isDeferringExternalCommit = isEditing
    }

    private func commitSliderChanges() {
        isDeferringExternalCommit = false
        windowAction = action
    }
}
