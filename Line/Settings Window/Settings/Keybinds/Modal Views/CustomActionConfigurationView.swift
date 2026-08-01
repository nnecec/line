//
//  CustomActionConfigurationView.swift
//  Line
//
//  Created by nnecec on 2024-04-27.
//

import Defaults
import SwiftUI

struct CustomActionConfigurationView: View {
    @Environment(\.settingsWindowProvider) private var settingsWindowProvider
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var windowAction: WindowAction
    @Binding var isPresented: Bool

    @State private var action: WindowAction
    @State private var currentTab: Tab = .position
    @State private var isDeferringExternalCommit = false

    private enum Tab: LocalizedStringKey, CaseIterable {
        case position = "Position", size = "Size"

        var image: Image {
            switch self {
            case .position:
                Image(systemName: "viewfinder")
            case .size:
                Image(systemName: "rectangle.expand.diagonal")
            }
        }
    }

    private let anchors: [CustomWindowActionAnchor] = [
        .topLeft, .top, .topRight, .left, .center, .right, .bottomLeft, .bottom, .bottomRight
    ]

    /// Extract custom action from WindowAction
    private var customAction: WindowAction.CustomWindowAction? {
        if case let .custom(custom) = action {
            return custom
        }
        return nil
    }

    private var actionUnit: CustomWindowActionUnit {
        customAction?.unit ?? .percentage
    }

    private var showMacOSCenterToggle: Bool {
        let anchor = customAction?.anchor ?? .center
        return anchor == .center || anchor == .macOSCenter
    }

    private var configurationScreen: NSScreen? {
        settingsWindowProvider.window?.screen ?? NSScreen.main ?? NSScreen.screens.first
    }

    private var configurationScreenSize: CGSize {
        configurationScreen?.frame.size ?? .zero
    }

    private let previewController = PreviewController()

    init(action: Binding<WindowAction>, isPresented: Binding<Bool>) {
        _windowAction = action
        _isPresented = isPresented
        _action = State(initialValue: action.wrappedValue)
    }

    var body: some View {
        Form {
            Section {
                ScreenView(isBlurred: customAction?.sizeMode != .custom) {
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
            TextField(
                "Custom Action",
                text: Binding(
                    get: { customAction?.name ?? "" },
                    set: { newName in
                        if case let .custom(custom) = action {
                            action = .custom(WindowAction.CustomWindowAction(
                                name: newName,
                                unit: custom.unit,
                                anchor: custom.anchor,
                                sizeMode: custom.sizeMode,
                                width: custom.width,
                                height: custom.height,
                                positionMode: custom.positionMode,
                                xPoint: custom.xPoint,
                                yPoint: custom.yPoint
                            ))
                        }
                    }
                )
            )
            .textFieldStyle(.roundedBorder)
        }

        Section {
            tabPicker()
            unitToggle()
        }

        Section {
            if currentTab == .position {
                positionConfiguration()
            } else {
                sizeConfiguration()
            }
        }
        .animation(reduceMotion ? nil : keybindConfigurationAnimation, value: customAction?.unit)
        .onAppear {
            // Ensure we have a custom action with default values
            if case let .custom(custom) = action {
                var updated = custom
                if updated.unit != custom.unit {
                    updated = WindowAction.CustomWindowAction(
                        name: custom.name,
                        unit: .percentage,
                        anchor: custom.anchor,
                        sizeMode: custom.sizeMode,
                        width: custom.width,
                        height: custom.height,
                        positionMode: custom.positionMode,
                        xPoint: custom.xPoint,
                        yPoint: custom.yPoint
                    )
                }
                if updated.sizeMode != custom.sizeMode {
                    updated = WindowAction.CustomWindowAction(
                        name: updated.name,
                        unit: updated.unit,
                        anchor: updated.anchor,
                        sizeMode: .custom,
                        width: updated.width,
                        height: updated.height,
                        positionMode: updated.positionMode,
                        xPoint: updated.xPoint,
                        yPoint: updated.yPoint
                    )
                }
                if custom.width == nil {
                    updated = WindowAction.CustomWindowAction(
                        name: updated.name,
                        unit: updated.unit,
                        anchor: updated.anchor,
                        sizeMode: updated.sizeMode,
                        width: 80,
                        height: updated.height,
                        positionMode: updated.positionMode,
                        xPoint: updated.xPoint,
                        yPoint: updated.yPoint
                    )
                }
                if custom.height == nil {
                    updated = WindowAction.CustomWindowAction(
                        name: updated.name,
                        unit: updated.unit,
                        anchor: updated.anchor,
                        sizeMode: updated.sizeMode,
                        width: updated.width,
                        height: 80,
                        positionMode: updated.positionMode,
                        xPoint: updated.xPoint,
                        yPoint: updated.yPoint
                    )
                }
                if updated.positionMode != custom.positionMode {
                    updated = WindowAction.CustomWindowAction(
                        name: updated.name,
                        unit: updated.unit,
                        anchor: updated.anchor,
                        sizeMode: updated.sizeMode,
                        width: updated.width,
                        height: updated.height,
                        positionMode: .generic,
                        xPoint: updated.xPoint,
                        yPoint: updated.yPoint
                    )
                }
                if updated.anchor != custom.anchor {
                    updated = WindowAction.CustomWindowAction(
                        name: updated.name,
                        unit: updated.unit,
                        anchor: .center,
                        sizeMode: updated.sizeMode,
                        width: updated.width,
                        height: updated.height,
                        positionMode: updated.positionMode,
                        xPoint: updated.xPoint,
                        yPoint: updated.yPoint
                    )
                }
                action = .custom(updated)
            }
        }
    }

    private func tabPicker() -> some View {
        Picker("Configuration", selection: $currentTab.animation(reduceMotion ? nil : keybindConfigurationAnimation)) {
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

    private func unitToggle() -> some View {
        Toggle("Use pixels", isOn: Binding(
            get: { actionUnit == .pixels },
            set: { usePixels in
                if case let .custom(custom) = action {
                    var updated = custom
                    updated = WindowAction.CustomWindowAction(
                        name: updated.name,
                        unit: usePixels ? .pixels : .percentage,
                        anchor: updated.anchor,
                        sizeMode: updated.sizeMode,
                        width: updated.width,
                        height: updated.height,
                        positionMode: updated.positionMode,
                        xPoint: updated.xPoint,
                        yPoint: updated.yPoint
                    )

                    let newUnit = usePixels ? CustomWindowActionUnit.pixels : .percentage
                    if newUnit == .percentage {
                        if let xPoint = updated.xPoint {
                            updated = WindowAction.CustomWindowAction(
                                name: updated.name,
                                unit: updated.unit,
                                anchor: updated.anchor,
                                sizeMode: updated.sizeMode,
                                width: updated.width,
                                height: updated.height,
                                positionMode: updated.positionMode,
                                xPoint: max(0, min(100, xPoint)),
                                yPoint: updated.yPoint
                            )
                        }
                        if let yPoint = updated.yPoint {
                            updated = WindowAction.CustomWindowAction(
                                name: updated.name,
                                unit: updated.unit,
                                anchor: updated.anchor,
                                sizeMode: updated.sizeMode,
                                width: updated.width,
                                height: updated.height,
                                positionMode: updated.positionMode,
                                xPoint: updated.xPoint,
                                yPoint: max(0, min(100, yPoint))
                            )
                        }
                        if let width = updated.width {
                            updated = WindowAction.CustomWindowAction(
                                name: updated.name,
                                unit: updated.unit,
                                anchor: updated.anchor,
                                sizeMode: updated.sizeMode,
                                width: max(0, min(100, width)),
                                height: updated.height,
                                positionMode: updated.positionMode,
                                xPoint: updated.xPoint,
                                yPoint: updated.yPoint
                            )
                        }
                        if let height = updated.height {
                            updated = WindowAction.CustomWindowAction(
                                name: updated.name,
                                unit: updated.unit,
                                anchor: updated.anchor,
                                sizeMode: updated.sizeMode,
                                width: updated.width,
                                height: max(0, min(100, height)),
                                positionMode: updated.positionMode,
                                xPoint: updated.xPoint,
                                yPoint: updated.yPoint
                            )
                        }
                    }
                    action = .custom(updated)
                }
            }
        ))
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
                                guard let configurationScreen else { return }
                                let context = ResizeContext(screen: configurationScreen)
                                context.setAction(to: BoundWindowAction(action: action, keybind: []), parent: nil)
                                previewController.open(context: context)
                            } else {
                                previewController.close()
                            }
                        },
                        perform: {}
                    )
                    .disabled(customAction?.sizeMode != .custom)

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

    @ViewBuilder
    private func positionConfiguration() -> some View {
        Toggle(
            "Use coordinates",
            isOn: Binding(
                get: {
                    customAction?.positionMode == .coordinates
                },
                set: { newValue in
                    withAnimation(reduceMotion ? nil : keybindConfigurationAnimation) {
                        if case let .custom(custom) = action {
                            action = .custom(WindowAction.CustomWindowAction(
                                name: custom.name,
                                unit: custom.unit,
                                anchor: custom.anchor,
                                sizeMode: custom.sizeMode,
                                width: custom.width,
                                height: custom.height,
                                positionMode: newValue ? .coordinates : .generic,
                                xPoint: custom.xPoint,
                                yPoint: custom.yPoint
                            ))
                        }
                    }
                }
            )
        )

        if customAction?.positionMode ?? .generic == .generic {
            KeybindOptionGrid(
                elements: anchors,
                selection: Binding(
                    get: {
                        let anchor = customAction?.anchor ?? .center
                        // since center/macOS center use the same icon on the picker
                        if anchor == .macOSCenter {
                            return .center
                        }
                        return anchor
                    },
                    set: { newValue in
                        withAnimation(reduceMotion ? nil : keybindConfigurationAnimation) {
                            if case let .custom(custom) = action {
                                action = .custom(WindowAction.CustomWindowAction(
                                    name: custom.name,
                                    unit: custom.unit,
                                    anchor: newValue,
                                    sizeMode: custom.sizeMode,
                                    width: custom.width,
                                    height: custom.height,
                                    positionMode: custom.positionMode,
                                    xPoint: custom.xPoint,
                                    yPoint: custom.yPoint
                                ))
                            }
                        }
                    }
                ),
                columns: 3,
                isSelectable: \.isSelectable
            ) { anchor in
                if let iconAction = anchor.iconAction {
                    IconView(action: iconAction)
                } else {
                    Color.clear
                }
            }

            if showMacOSCenterToggle {
                Toggle(
                    isOn: Binding(
                        get: {
                            customAction?.anchor == .macOSCenter
                        },
                        set: { useMacOSCenter in
                            if case let .custom(custom) = action {
                                action = .custom(WindowAction.CustomWindowAction(
                                    name: custom.name,
                                    unit: custom.unit,
                                    anchor: useMacOSCenter ? .macOSCenter : .center,
                                    sizeMode: custom.sizeMode,
                                    width: custom.width,
                                    height: custom.height,
                                    positionMode: custom.positionMode,
                                    xPoint: custom.xPoint,
                                    yPoint: custom.yPoint
                                ))
                            }
                        }
                    )
                ) {
                    Text("Use macOS center", comment: "Toggle to enable macOS-style centering in custom actions")
                }
            }
        } else {
            KeybindValueSlider(
                "X",
                value: Binding(
                    get: {
                        customAction?.xPoint ?? 0
                    },
                    set: { newValue in
                        if case let .custom(custom) = action {
                            action = .custom(WindowAction.CustomWindowAction(
                                name: custom.name,
                                unit: custom.unit,
                                anchor: custom.anchor,
                                sizeMode: custom.sizeMode,
                                width: custom.width,
                                height: custom.height,
                                positionMode: custom.positionMode,
                                xPoint: actionUnit.roundIfNeeded(newValue),
                                yPoint: custom.yPoint
                            ))
                        }
                    }
                ),
                in: actionUnit == .percentage ? 0...100 : 0...Double(configurationScreenSize.width),
                unit: actionUnit,
                onEditingChanged: handleSliderEditingChanged,
                onEditingCommit: commitSliderChanges
            )

            KeybindValueSlider(
                "Y",
                value: Binding(
                    get: {
                        customAction?.yPoint ?? 0
                    },
                    set: { newValue in
                        if case let .custom(custom) = action {
                            action = .custom(WindowAction.CustomWindowAction(
                                name: custom.name,
                                unit: custom.unit,
                                anchor: custom.anchor,
                                sizeMode: custom.sizeMode,
                                width: custom.width,
                                height: custom.height,
                                positionMode: custom.positionMode,
                                xPoint: custom.xPoint,
                                yPoint: actionUnit.roundIfNeeded(newValue)
                            ))
                        }
                    }
                ),
                in: actionUnit == .percentage ? 0...100 : 0...Double(configurationScreenSize.height),
                unit: actionUnit,
                onEditingChanged: handleSliderEditingChanged,
                onEditingCommit: commitSliderChanges
            )
        }
    }

    @ViewBuilder
    private func sizeConfiguration() -> some View {
        KeybindOptionGrid(
            elements: CustomWindowActionSizeMode.allCases,
            selection: Binding(
                get: {
                    customAction?.sizeMode ?? .custom
                },
                set: { newValue in
                    withAnimation(reduceMotion ? nil : keybindConfigurationAnimation) {
                        if case let .custom(custom) = action {
                            action = .custom(WindowAction.CustomWindowAction(
                                name: custom.name,
                                unit: custom.unit,
                                anchor: custom.anchor,
                                sizeMode: newValue,
                                width: custom.width,
                                height: custom.height,
                                positionMode: custom.positionMode,
                                xPoint: custom.xPoint,
                                yPoint: custom.yPoint
                            ))
                        }
                    }
                }
            ),
            columns: 3
        ) { mode in
            VStack(spacing: 4) {
                mode.image
                Text(mode.name)
            }
            .padding(.vertical, 15)
            .compositingGroup()
        }

        if customAction?.sizeMode ?? .custom == .custom {
            KeybindValueSlider(
                "Width",
                value: Binding(
                    get: {
                        customAction?.width ?? 100
                    },
                    set: { newValue in
                        if case let .custom(custom) = action {
                            action = .custom(WindowAction.CustomWindowAction(
                                name: custom.name,
                                unit: custom.unit,
                                anchor: custom.anchor,
                                sizeMode: custom.sizeMode,
                                width: actionUnit.roundIfNeeded(newValue),
                                height: custom.height,
                                positionMode: custom.positionMode,
                                xPoint: custom.xPoint,
                                yPoint: custom.yPoint
                            ))
                        }
                    }
                ),
                in: actionUnit == .percentage ? 0...100 : 0...Double(configurationScreenSize.width),
                unit: actionUnit,
                onEditingChanged: handleSliderEditingChanged,
                onEditingCommit: commitSliderChanges
            )

            KeybindValueSlider(
                "Height",
                value: Binding(
                    get: {
                        customAction?.height ?? 100
                    },
                    set: { newValue in
                        if case let .custom(custom) = action {
                            action = .custom(WindowAction.CustomWindowAction(
                                name: custom.name,
                                unit: custom.unit,
                                anchor: custom.anchor,
                                sizeMode: custom.sizeMode,
                                width: custom.width,
                                height: actionUnit.roundIfNeeded(newValue),
                                positionMode: custom.positionMode,
                                xPoint: custom.xPoint,
                                yPoint: custom.yPoint
                            ))
                        }
                    }
                ),
                in: actionUnit == .percentage ? 0...100 : 0...Double(configurationScreenSize.height),
                unit: actionUnit,
                onEditingChanged: handleSliderEditingChanged,
                onEditingCommit: commitSliderChanges
            )
        }
    }

    private func handleSliderEditingChanged(_ isEditing: Bool) {
        isDeferringExternalCommit = isEditing
    }

    private func commitSliderChanges() {
        isDeferringExternalCommit = false
        windowAction = action
    }
}

let keybindConfigurationAnimation = Animation.easeInOut(duration: 0.20)

struct KeybindOptionGrid<Element: Hashable, Content: View>: View {
    let elements: [Element]
    @Binding var selection: Element
    let columns: Int
    let isSelectable: (Element) -> Bool
    let content: (Element) -> Content

    init(
        elements: [Element],
        selection: Binding<Element>,
        columns: Int,
        isSelectable: @escaping (Element) -> Bool = { _ in true },
        @ViewBuilder content: @escaping (Element) -> Content
    ) {
        self.elements = elements
        self._selection = selection
        self.columns = columns
        self.isSelectable = isSelectable
        self.content = content
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 6) {
            ForEach(Array(elements.enumerated()), id: \.offset) { _, element in
                if isSelectable(element) {
                    Button {
                        selection = element
                    } label: {
                        cellContent(for: element)
                    }
                    .buttonStyle(.plain)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selection == element ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.secondary.opacity(selection == element ? 0.35 : 0.15), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    cellContent(for: element)
                        .opacity(0)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: columns)
    }

    private func cellContent(for element: Element) -> some View {
        content(element)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
    }
}

struct KeybindValueSlider: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: CustomWindowActionUnit
    let onEditingChanged: (Bool) -> ()
    let onEditingCommit: () -> ()

    init(
        _ title: LocalizedStringKey,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        unit: CustomWindowActionUnit,
        onEditingChanged: @escaping (Bool) -> (),
        onEditingCommit: @escaping () -> ()
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.unit = unit
        self.onEditingChanged = onEditingChanged
        self.onEditingCommit = onEditingCommit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(title)

                Spacer()

                TextField("", value: $value, format: .number.precision(unit.fractionLength))
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 72)
                    .accessibilityLabel(Text(title))
                    .onSubmit(onEditingCommit)

                Text(unit.suffix)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 20, alignment: .leading)
            }

            Slider(
                value: $value,
                in: range,
                onEditingChanged: { isEditing in
                    onEditingChanged(isEditing)
                    if !isEditing {
                        onEditingCommit()
                    }
                }
            )
        }
        .padding(.vertical, 4)
    }
}
