//
//  DirectionPickerView.swift
//  Line
//
//  Created by nnecec on 2025-10-18.
//

import SwiftUI

struct DirectionPickerView: View {
    @State private var searchText = ""
    @State private var searchResults: [WindowDirection] = []
    @State private var arrowSelection: WindowDirection?
    @FocusState private var isSearchFocused: Bool

    @Binding private var direction: WindowDirection
    @Binding private var isPresented: Bool
    private let isInCycle: Bool
    private let eventMonitorID = "keybindDirectionPicker"

    private var sections: [DirectionPickerSection] {
        DirectionPickerSection.windowDirections
    }

    private var moreSection: DirectionPickerSection {
        let title = String(localized: "More", comment: "Section header in the action picker of the Keybinds tab")
        if isInCycle {
            return .init(title, [WindowDirection.custom])
        } else {
            return .init(title, [WindowDirection.custom, WindowDirection.cycle])
        }
    }

    private var sectionItems: [WindowDirection] {
        sections
            .map(\.items)
            .flatMap(\.self)
    }

    private var displayedItems: [WindowDirection] {
        searchResults.isEmpty ? sectionItems + moreSection.items : searchResults
    }

    init(direction: Binding<WindowDirection>, isInCycle: Bool, isPresented: Binding<Bool>) {
        self._direction = direction
        self._isPresented = isPresented
        self.isInCycle = isInCycle
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField(
                String(localized: "Search for a window action", defaultValue: "Search…"),
                text: $searchText
            )
            .textFieldStyle(.plain)
            .focused($isSearchFocused)
            .padding(12)

            Divider()

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        if searchResults.isEmpty {
                            sectionsView
                        } else {
                            searchResultsView
                        }
                    }
                    .padding(8)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onAppear {
                    setupEventMonitor(proxy: proxy)
                }
            }
        }
        .onAppear {
            searchText = ""
            computeSearchResults()
            Task { @MainActor in
                isSearchFocused = true
            }
        }
        .onDisappear {
            searchText = ""
            PickerListEventMonitorManager.shared.removeMonitor(for: eventMonitorID)
        }
        .onChange(of: searchText) {
            arrowSelection = nil
            computeSearchResults()
        }
    }

    private var sectionsView: some View {
        ForEach(sections + [moreSection]) { section in
            Section {
                ForEach(section.items, id: \.self) { item in
                    row(for: item)
                }
            } header: {
                Text(section.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding([.top, .horizontal], 6)
            }
        }
    }

    private var searchResultsView: some View {
        ForEach(searchResults) { item in
            row(for: item)
        }
    }

    private func row(for item: WindowDirection) -> some View {
        DirectionPickerRow(
            item: item,
            isHighlighted: direction == item || arrowSelection == item
        ) {
            select(item)
        }
    }

    private func computeSearchResults() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }

        let key = searchText.lowercased()

        let matches = sectionItems
            .compactMap { item -> (WindowDirection, Int)? in
                if let score = fuzzyScore(item.name, key) {
                    return (item, score)
                }
                return nil
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)

        searchResults = matches + moreSection.items
    }

    private func setupEventMonitor(proxy: ScrollViewProxy) {
        PickerListEventMonitorManager.shared.addMonitor(
            for: eventMonitorID,
            matching: [.keyDown]
        ) { event in
            switch event.keyCode {
            case .kVK_DownArrow:
                updateArrowSelection(increment: true, proxy: proxy)
            case .kVK_UpArrow:
                updateArrowSelection(increment: false, proxy: proxy)
            case .kVK_Return:
                if let arrowSelection {
                    select(arrowSelection)
                }
            case .kVK_Escape:
                isPresented = false
            default:
                return event
            }

            return nil
        }
    }

    private func updateArrowSelection(increment: Bool, proxy: ScrollViewProxy) {
        let items = displayedItems
        guard !items.isEmpty else { return }

        let currentIndex = items.firstIndex(where: { $0 == arrowSelection }) ?? (increment ? -1 : items.count)
        let nextIndex = currentIndex + (increment ? 1 : -1)
        guard items.indices.contains(nextIndex) else { return }

        let newSelection = items[nextIndex]
        arrowSelection = newSelection

        withAnimation(.easeInOut(duration: 0.15)) {
            proxy.scrollTo(newSelection, anchor: .center)
        }
    }

    private func select(_ item: WindowDirection) {
        direction = item
        isPresented = false
        PickerListEventMonitorManager.shared.removeMonitor(for: eventMonitorID)
    }

    private func fuzzyScore(_ text: String, _ pattern: String) -> Int? {
        let text = text.lowercased()
        let pattern = pattern.lowercased()

        // Strong prefix match
        if text.hasPrefix(pattern) {
            return 0
        }

        // Contains substring
        if text.contains(pattern) {
            return 1
        }

        // Subsequence fuzzy match (letters appear in order)
        var tIndex = text.startIndex
        var pIndex = pattern.startIndex
        while tIndex < text.endIndex, pIndex < pattern.endIndex {
            if text[tIndex] == pattern[pIndex] {
                pIndex = text.index(after: pIndex)
            }
            tIndex = text.index(after: tIndex)
        }

        if pIndex == pattern.endIndex {
            return 2
        }

        return nil
    }
}

private struct DirectionPickerRow: View {
    let item: WindowDirection
    let isHighlighted: Bool
    let select: () -> ()

    @State private var isHovering = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: 8) {
                IconView(direction: item)

                Text(item.name)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(isHighlighted ? 0.35 : 0), lineWidth: 1)
        }
        .onHover { isHovering = $0 }
    }

    private var backgroundColor: Color {
        if isHighlighted {
            Color.accentColor.opacity(0.18)
        } else if isHovering {
            Color.secondary.opacity(0.10)
        } else {
            Color.clear
        }
    }
}

private struct DirectionPickerSection: Identifiable, Hashable {
    var id: String { title }

    let title: String
    let items: [WindowDirection]

    init(_ title: String, _ items: [WindowDirection]) {
        self.title = title
        self.items = items
    }
}

private extension DirectionPickerSection {
    static var windowDirections: [DirectionPickerSection] {
        [
            .init(String(localized: "General", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.general),
            .init(String(localized: "Halves", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.halves),
            .init(String(localized: "Quarters", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.quarters),
            .init(String(localized: "Horizontal Thirds", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.horizontalThirds),
            .init(String(localized: "Vertical Thirds", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.verticalThirds),
            .init(String(localized: "Horizontal Fourths", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.horizontalFourths),
            .init(String(localized: "Screen Switching", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.screenSwitching),
            .init(String(localized: "Size Adjustment", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.sizeAdjustment),
            .init(String(localized: "Shrink", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.shrink),
            .init(String(localized: "Grow", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.grow),
            .init(String(localized: "Move", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.move),
            .init(String(localized: "Focus", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.focus),
            .init(String(localized: "Stash", comment: "Section header in the action picker of the Keybinds tab"), [WindowDirection.stash, WindowDirection.unstash]),
            .init(String(localized: "Go Back", comment: "Section header in the action picker of the Keybinds tab"), [WindowDirection.initialFrame, WindowDirection.undo])
        ]
    }
}
