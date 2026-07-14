//
//  CycleActionConfigurationView.swift
//  Line
//
//  Created by nnecec on 2024-05-03.
//

import Defaults
import SwiftUI

struct CycleActionItem: Identifiable, Equatable {
    let id: UUID
    var action: WindowAction
}

enum CycleActionSelectionPolicy {
    static func items(from action: WindowAction) -> [CycleActionItem] {
        guard case let .cycle(actions) = action else {
            return []
        }

        return actions.map { CycleActionItem(id: UUID(), action: $0) }
    }

    static func selectedIndices(in items: [CycleActionItem], selectedIDs: Set<CycleActionItem.ID>) -> [Int] {
        items.indices.filter { selectedIDs.contains(items[$0].id) }
    }

    @discardableResult
    static func addNoAction(to items: inout [CycleActionItem], selectedIDs: inout Set<CycleActionItem.ID>) -> CycleActionItem.ID {
        let newItem = CycleActionItem(id: UUID(), action: .special(.noAction))
        items.insert(newItem, at: 0)
        selectedIDs = [newItem.id]
        return newItem.id
    }

    static func removeSelected(from items: inout [CycleActionItem], selectedIDs: inout Set<CycleActionItem.ID>) {
        items.removeAll { selectedIDs.contains($0.id) }
        selectedIDs.removeAll()
    }

    static func deleteItems(at offsets: IndexSet, from items: inout [CycleActionItem], selectedIDs: inout Set<CycleActionItem.ID>) {
        let deletedIDs = Set(offsets.compactMap { index in
            items.indices.contains(index) ? items[index].id : nil
        })
        items.remove(atOffsets: offsets)
        selectedIDs.subtract(deletedIDs)
    }

    static func moveItems(from source: IndexSet, to destination: Int, in items: inout [CycleActionItem]) {
        items.move(fromOffsets: source, toOffset: destination)
    }

    static func moveSelectedItem(by offset: Int, in items: inout [CycleActionItem], selectedIDs: Set<CycleActionItem.ID>) {
        guard
            selectedIDs.count == 1,
            let selectedID = selectedIDs.first,
            let index = items.firstIndex(where: { $0.id == selectedID }),
            let targetIndex = items.index(index, offsetBy: offset, limitedBy: items.endIndex),
            items.indices.contains(targetIndex)
        else {
            return
        }

        items.swapAt(index, targetIndex)
    }
}

struct CycleActionConfigurationView: View {
    @Binding var windowAction: WindowAction
    @Binding var isPresented: Bool

    @State private var cycleItems: [CycleActionItem]
    @State private var selectedCycleItemIDs = Set<CycleActionItem.ID>()

    private var selectedCycleIndices: [Int] {
        CycleActionSelectionPolicy.selectedIndices(in: cycleItems, selectedIDs: selectedCycleItemIDs)
    }

    private var canMoveSelectionUp: Bool {
        selectedCycleIndices.count == 1 && selectedCycleIndices[0] > 0
    }

    private var canMoveSelectionDown: Bool {
        selectedCycleIndices.count == 1 && selectedCycleIndices[0] < cycleItems.count - 1
    }

    init(action: Binding<WindowAction>, isPresented: Binding<Bool>) {
        self._windowAction = action
        self._isPresented = isPresented
        self._cycleItems = State(initialValue: CycleActionSelectionPolicy.items(from: action.wrappedValue))
    }

    var body: some View {
        Form {
            Section {
                TextField("Cycle Keybind", text: Binding(
                    get: {
                        // Cycle actions don't have a name property
                        "Cycle"
                    },
                    set: { _ in
                        // No-op: cycle actions don't have editable names
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .disabled(true)
            }

            Section {
                HStack(spacing: 8) {
                    Button("Add", action: addCycleItem)

                    Button("Remove", role: .destructive) {
                        removeSelectedCycleItems()
                    }
                    .disabled(selectedCycleItemIDs.isEmpty)

                    Button {
                        moveSelectedCycleItem(by: -1)
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(!canMoveSelectionUp)
                    .help("Move selected cycle item up.")

                    Button {
                        moveSelectedCycleItem(by: 1)
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .disabled(!canMoveSelectionDown)
                    .help("Move selected cycle item down.")
                }
                .buttonStyle(.bordered)

                if !cycleItems.isEmpty {
                    List(selection: $selectedCycleItemIDs) {
                        ForEach(Array(cycleItems.enumerated()), id: \.element.id) { index, item in
                            let boundAction = BoundWindowAction(action: item.action, keybind: [])
                            KeybindItemView(
                                .constant(boundAction),
                                cycleIndex: index + 1
                            )
                            .environmentObject(KeybindsConfigurationModel())
                            .tag(item.id)
                        }
                        .onDelete(perform: deleteCycleItems)
                        .onMove(perform: moveCycleItems)
                    }
                    .frame(minHeight: 220)
                } else {
                    emptyCycleView
                }
            }

            Section {
                HStack {
                    Spacer()

                    Button {
                        isPresented = false
                    } label: {
                        Text("Close", comment: "Label for a button that closes a modal window")
                    }
                    .keyboardShortcut(.cancelAction)
                }
                .buttonStyle(.bordered)
            }
        }
        .onAppear {
            if case .cycle = windowAction {
                return
            }

            cycleItems = []
            commitCycleItems()
        }
    }

    private var emptyCycleView: some View {
        VStack(spacing: 4) {
            Text("Nothing to cycle through")
                .font(.title3)
            Text("Press \"Add\" to add a cycle item")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 160)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.20), lineWidth: 1)
        }
    }

    private func addCycleItem() {
        CycleActionSelectionPolicy.addNoAction(to: &cycleItems, selectedIDs: &selectedCycleItemIDs)
        commitCycleItems()
    }

    private func removeSelectedCycleItems() {
        CycleActionSelectionPolicy.removeSelected(from: &cycleItems, selectedIDs: &selectedCycleItemIDs)
        commitCycleItems()
    }

    private func deleteCycleItems(at offsets: IndexSet) {
        CycleActionSelectionPolicy.deleteItems(at: offsets, from: &cycleItems, selectedIDs: &selectedCycleItemIDs)
        commitCycleItems()
    }

    private func moveCycleItems(from source: IndexSet, to destination: Int) {
        CycleActionSelectionPolicy.moveItems(from: source, to: destination, in: &cycleItems)
        commitCycleItems()
    }

    private func moveSelectedCycleItem(by offset: Int) {
        CycleActionSelectionPolicy.moveSelectedItem(by: offset, in: &cycleItems, selectedIDs: selectedCycleItemIDs)
        commitCycleItems()
    }

    private func commitCycleItems() {
        windowAction = .cycle(cycleItems.map(\.action))
    }
}
