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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding private var direction: WindowDirection
    @Binding private var isPresented: Bool
    private let isInCycle: Bool
    private let eventMonitorID = "keybindDirectionPicker"

    private var isSearching: Bool {
        !searchText.isEmpty
    }

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
        isSearching ? searchResults : sectionItems + moreSection.items
    }

    init(direction: Binding<WindowDirection>, isInCycle: Bool, isPresented: Binding<Bool>) {
        self._direction = direction
        self._isPresented = isPresented
        self.isInCycle = isInCycle
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                TextField(
                    String(localized: "Search for a window action", defaultValue: "Search…"),
                    text: $searchText
                )
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)

            Divider()
                .opacity(0.6)

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        if !isSearching {
                            sectionsView
                        } else if searchResults.isEmpty {
                            ContentUnavailableView {
                                Label("No matching actions", systemImage: "magnifyingglass")
                            } description: {
                                Text("Try a different search term.")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                        } else {
                            searchResultsView
                        }
                    }
                    .padding(8)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                    .padding(.top, 8)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 2)
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

        searchResults = DirectionPickerSearchPolicy.results(
            for: searchText,
            in: sectionItems + moreSection.items
        )
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

        if reduceMotion {
            proxy.scrollTo(newSelection, anchor: .center)
        } else {
            withAnimation(.easeInOut(duration: 0.15)) {
                proxy.scrollTo(newSelection, anchor: .center)
            }
        }
    }

    private func select(_ item: WindowDirection) {
        direction = item
        isPresented = false
        PickerListEventMonitorManager.shared.removeMonitor(for: eventMonitorID)
    }
}

private struct DirectionPickerRow: View {
    let item: WindowDirection
    let isHighlighted: Bool
    let select: () -> ()

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let cornerRadius: CGFloat = 8

    var body: some View {
        Button(action: select) {
            HStack(spacing: 10) {
                IconView(direction: item)
                    .opacity(isHighlighted ? 1 : 0.92)

                Text(item.name)
                    .fontWeight(isHighlighted ? .medium : .regular)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if isHighlighted {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .transition(
                            reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.85))
                        )
                }
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .fill(backgroundColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.14), value: isHighlighted)
        .animation(reduceMotion ? nil : .snappy(duration: 0.12), value: isHovering)
        .onHover { isHovering = $0 }
    }

    private var backgroundColor: Color {
        if isHighlighted {
            Color.accentColor.opacity(0.16)
        } else if isHovering {
            Color.secondary.opacity(0.09)
        } else {
            Color.clear
        }
    }

    private var borderColor: Color {
        if isHighlighted {
            Color.accentColor.opacity(0.28)
        } else if isHovering {
            Color.secondary.opacity(0.12)
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
