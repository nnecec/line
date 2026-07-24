//
//  KeybindsConfigurationView.swift
//  Line
//
//  Created by nnecec on 2024-04-20.
//

import Defaults
import SwiftUI

final class KeybindsConfigurationModel: ObservableObject {
    @Published var currentEventMonitor: LocalEventMonitor?
    @Published var selectedKeybinds = Set<BoundWindowAction>()
    @Published var selectedKeybindIDs = Set<UUID>()
}

struct KeybindsConfigurationView: View {
    @EnvironmentObject private var settingsState: SettingsState
    @StateObject private var model = KeybindsConfigurationModel()

    @Default(.triggerKey) private var triggerKey
    @Default(.sideDependentTriggerKey) private var sideDependentTriggerKey
    @Default(.triggerDelay) private var triggerDelay
    @Default(.cycleModeRestartEnabled) private var cycleModeRestartEnabled
    @Default(.cycleBackwardsOnShiftPressed) private var cycleBackwardsOnShiftPressed
    @Default(.doubleClickToTrigger) private var doubleClickToTrigger
    @Default(.middleClickTriggersLine) private var middleClickTriggersLine
    @Default(.enableTriggerDelayOnMiddleClick) private var enableTriggerDelayOnMiddleClick
    @Default(.keybinds) private var keybinds

    /// If the user has "enabled" the trigger delay.
    private var useTriggerDelay: Bool {
        Defaults[.triggerDelay] != 0
    }

    /// Is there at least one keybind action that is a cycle?
    private var isCycleActionPresentInKeybinds: Bool {
        keybinds.contains(where: { $0.cycle != nil })
    }

    /// Is Shift used in the trigger key?
    private var isShiftUsedByTriggerKey: Bool {
        triggerKey.map(\.baseModifier).contains(.kVK_Shift)
    }

    private var showMiddleClickTriggerDelayOption: Bool {
        middleClickTriggersLine && useTriggerDelay
    }

    private var showCycleRestartOption: Bool {
        isCycleActionPresentInKeybinds
    }

    private var showCycleBackwardsOption: Bool {
        isCycleActionPresentInKeybinds && !isShiftUsedByTriggerKey
    }

    private var conflictingKeybindIDs: Set<BoundWindowAction.ID> {
        KeybindBindingPolicy.conflictingIDs(in: keybinds, triggerKey: triggerKey)
    }

    var body: some View {
        Form {
            // Show a diagnostic recovery prompt when stored keybinds are missing.
            if keybinds.isEmpty {
                Section {
                    SettingsEmptyState(
                        systemImage: "keyboard.badge.ellipsis",
                        title: "Keybind list is empty",
                        message: "This can make every keybind show a red warning icon. Restore the default configuration below.",
                        actionTitle: "Restore Default Keybinds",
                        action: {
                            keybinds = BoundWindowAction.defaultKeybinds
                        }
                    )
                }
            }

            triggerKeySection
            settingsSection
            keybindsSection
        }
        .settingsFormPanel(maxWidth: 560)
        .animation(
            .default,
            value: [
                showMiddleClickTriggerDelayOption,
                cycleModeRestartEnabled,
                showCycleBackwardsOption
            ]
        )
    }

    private var triggerKeySection: some View {
        Section {
            Text("Hold this modifier to reveal Line’s window actions. The same key also opens the grid thumbnail when a grid action is selected.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TriggerKeycorder($triggerKey)
                .environmentObject(model)
        } header: {
            Text("Trigger Key", comment: "Section header shown in settings")
        }
    }

    @ViewBuilder
    private var settingsSection: some View {
        Section {
            Toggle(isOn: $sideDependentTriggerKey) {
                SettingsRowLabel(
                    "Treat left and right keys differently",
                    detail: "Let left Command and right Command behave as separate trigger keys.",
                    systemImage: "keyboard"
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Trigger delay")
                    Spacer()
                    HStack(spacing: 0) {
                        Text(triggerDelay, format: .number.precision(.fractionLength(1...1)))
                        Text("s", comment: "Unit symbol: seconds")
                    }
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
                }

                Slider(value: $triggerDelay, in: 0...1, step: 0.1)
            }

            Toggle(isOn: $doubleClickToTrigger) {
                SettingsRowLabel(
                    "Double-click to trigger",
                    detail: "Open Line only after the trigger key is pressed twice.",
                    systemImage: "rectangle.stack.badge.play"
                )
            }

            Toggle(isOn: $middleClickTriggersLine) {
                SettingsRowLabel(
                    "Middle-click to trigger",
                    detail: "Use the mouse wheel button as an additional trigger.",
                    systemImage: "computermouse"
                )
            }

            if showMiddleClickTriggerDelayOption {
                Toggle(isOn: $enableTriggerDelayOnMiddleClick) {
                    SettingsRowLabel(
                        "Apply trigger delay on middle-click",
                        detail: "Use the same delay before a middle-click opens Line.",
                        systemImage: "timer"
                    )
                }
            }
        } header: {
            Text("Trigger Options", comment: "Section header shown in settings for trigger-related options")
        }

        if showCycleRestartOption || showCycleBackwardsOption {
            Section {
                if showCycleRestartOption {
                    Toggle(isOn: $cycleModeRestartEnabled) {
                        SettingsRowLabel(
                            "Always start cycles from first item",
                            detail: "Each cycle action begins from its first item instead of resuming.",
                            systemImage: "arrow.counterclockwise"
                        )
                    }
                    .help("By default, Line resumes cycles from where you last left off in each window.")
                }

                if showCycleBackwardsOption {
                    Toggle(isOn: $cycleBackwardsOnShiftPressed) {
                        SettingsRowLabel(
                            "Cycle backward with Shift",
                            detail: "Hold Shift while triggering a cycle to move in reverse.",
                            systemImage: "shift"
                        )
                    }
                }
            } header: {
                Text("Cycles", comment: "Section header shown in settings")
            }
        }
    }

    private var keybindsSection: some View {
        let duplicateKeybindIDs = conflictingKeybindIDs

        return Section {
            SettingsListToolbar(
                onAdd: {
                    keybinds.insert(BoundWindowAction(action: .special(.noAction), keybind: []), at: 0)
                },
                addHelp: "Add a new keybind (⌘N)",
                addKeyboardShortcut: "n",
                onRemove: removeSelectedKeybinds,
                removeHelp: "Remove selected keybinds (⌫)",
                canRemove: !model.selectedKeybindIDs.isEmpty
            )

            List(selection: $model.selectedKeybindIDs) {
                if keybinds.isEmpty {
                    SettingsEmptyState(
                        systemImage: "plus.rectangle.on.rectangle",
                        title: "No keybinds",
                        message: "Press Add to add a keybind"
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach($keybinds) { keybind in
                        KeybindItemView(
                            keybind,
                            triggerKey: triggerKey,
                            hasDuplicateKeybinds: duplicateKeybindIDs.contains(keybind.wrappedValue.id)
                        )
                        .environmentObject(model)
                        .tag(keybind.wrappedValue.id)
                        .contextMenu {
                            Button("Remove Keybind", role: .destructive) {
                                removeKeybind(id: keybind.wrappedValue.id)
                            }
                        }
                    }
                    .onMove(perform: moveKeybinds)
                }
            }
            .frame(minHeight: 180)
            .onDeleteCommand(perform: removeSelectedKeybinds)
            .onAppear(perform: updatePreviewForSelection)
            .onReceive(model.$selectedKeybindIDs) { _ in
                updatePreviewForSelection()
            }
            .onDisappear {
                settingsState.isPreviewingUserSelection = false
            }
        } header: {
            Text("Keybinds", comment: "Section header shown in settings")
        } footer: {
            Text(
                "Select one shortcut to preview its action. Drag to reorder. Press Delete to remove the selection.",
                comment: "Footer explaining keybind list interactions"
            )
        }
    }

    private func removeSelectedKeybinds() {
        keybinds.removeAll { model.selectedKeybindIDs.contains($0.id) }
        model.selectedKeybindIDs.removeAll()
        updatePreviewForSelection()
    }

    private func removeKeybind(id: BoundWindowAction.ID) {
        keybinds.removeAll { $0.id == id }
        model.selectedKeybindIDs.remove(id)
        updatePreviewForSelection()
    }

    private func moveKeybinds(from source: IndexSet, to destination: Int) {
        keybinds.move(fromOffsets: source, toOffset: destination)
    }

    private func updatePreviewForSelection() {
        let selectedKeybinds = keybinds.filter { model.selectedKeybindIDs.contains($0.id) }
        model.selectedKeybinds = Set(selectedKeybinds)

        if selectedKeybinds.count == 1, let action = selectedKeybinds.first {
            settingsState.isPreviewingUserSelection = true
            settingsState.setPreviewedAction(to: action)
        } else {
            settingsState.isPreviewingUserSelection = false
        }
    }
}

