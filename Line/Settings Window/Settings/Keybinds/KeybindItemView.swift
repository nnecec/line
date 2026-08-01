//
//  KeybindItemView.swift
//  Line
//
//  Created by nnecec on 2024-05-03.
//

import SwiftUI

struct KeybindItemView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var action: BoundWindowAction
    @Binding private var boundAction: BoundWindowAction

    @State private var isConfiguringCustom: Bool = false
    @State private var isConfiguringCycle: Bool = false
    private let cycleIndex: Int?
    private let triggerKey: Set<CGKeyCode>
    private let hasDuplicateKeybinds: Bool
    @State private var isDirectionPickerPresented = false

    init(
        _ action: Binding<BoundWindowAction>,
        cycleIndex: Int? = nil,
        triggerKey: Set<CGKeyCode> = [],
        hasDuplicateKeybinds: Bool = false
    ) {
        self.action = action.wrappedValue
        self._boundAction = action
        self.cycleIndex = cycleIndex
        self.triggerKey = triggerKey
        self.hasDuplicateKeybinds = hasDuplicateKeybinds
    }

    var body: some View {
        HStack(spacing: 8) {
            titleAndButtons
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(0)

            keybindCombination
                .layoutPriority(1)
        }
        .padding(.horizontal, 12)
        .onChange(of: action.direction) {
            if action.isCustomizable {
                isConfiguringCustom = true
            }
            if action.direction == .cycle {
                isConfiguringCycle = true
            }
        }
        .onChange(of: action) { _, newValue in boundAction = newValue }
    }

    private var titleAndButtons: some View {
        HStack(spacing: 4) {
            label()

            Group {
                if action.isCustomizable {
                    Button {
                        isConfiguringCustom = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .frame(minWidth: 28, minHeight: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Customize this action's custom frame.")
                    .sheet(isPresented: $isConfiguringCustom) {
                        if case .custom = action.action {
                            CustomActionConfigurationView(
                                action: Binding(
                                    get: { action.action },
                                    set: { action = BoundWindowAction(id: action.id, action: $0, keybind: action.keybind, bypassTriggerKey: action.bypassTriggerKey) }
                                ),
                                isPresented: $isConfiguringCustom
                            )
                            .frame(width: 400)
                        } else {
                            StashActionConfigurationView(
                                action: Binding(
                                    get: { action.action },
                                    set: { action = BoundWindowAction(id: action.id, action: $0, keybind: action.keybind, bypassTriggerKey: action.bypassTriggerKey) }
                                ),
                                isPresented: $isConfiguringCustom
                            )
                            .frame(width: 400)
                        }
                    }
                    .help("Customize this action's custom frame.")
                }

                if action.direction == .cycle {
                    Button {
                        isConfiguringCycle = true
                    } label: {
                        Image(systemName: "repeat")
                            .frame(minWidth: 28, minHeight: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Customize what this action cycles through.")
                    .sheet(isPresented: $isConfiguringCycle) {
                        CycleActionConfigurationView(
                            action: Binding(
                                get: { action.action },
                                set: { action = BoundWindowAction(id: action.id, action: $0, keybind: action.keybind, bypassTriggerKey: action.bypassTriggerKey) }
                            ),
                            isPresented: $isConfiguringCycle
                        )
                        .frame(width: 400)
                    }
                    .help("Customize what this action cycles through.")
                }
            }
            .font(.title3)
            .foregroundStyle(.secondary)
        }
        .popover(isPresented: $isDirectionPickerPresented, arrowEdge: .top) {
            DirectionPickerView(
                direction: Binding(
                    get: { action.direction },
                    set: { newDirection in
                        // Convert WindowDirection to WindowAction
                        let newAction = newDirection.toWindowAction()
                        action = BoundWindowAction(id: action.id, action: newAction, keybind: action.keybind, bypassTriggerKey: action.bypassTriggerKey)
                    }
                ),
                isInCycle: cycleIndex != nil,
                isPresented: $isDirectionPickerPresented
            )
            .frame(width: 300, height: 300)
        }
        .onChange(of: isDirectionPickerPresented) {
            if !isDirectionPickerPresented {
                PickerListEventMonitorManager.shared.removeAllMonitors()
            }
        }
    }

    private var keybindCombination: some View {
        HStack {
            if let cycleIndex {
                Text("\(cycleIndex)")
                    .frame(width: 27, height: 27)
                    .keybindKeyCap()
            } else {
                HStack(spacing: 6) {
                    keycorderSection()
                        .padding(.leading, 4)

                    if hasDuplicateKeybinds {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .transition(
                                reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.25))
                            )
                            .help("There are other keybinds that conflict with this key combination.")
                    }
                }
                .fixedSize()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helper Methods

    /// Switches to standard mode (keeps the keybind)
    private func restoreStandardMode() {
        action = BoundWindowAction(
            id: action.id,
            action: action.action,
            keybind: action.keybind.subtracting(triggerKey),
            bypassTriggerKey: false
        )
    }

    /// Merges trigger key into action key and switches to bypass mode
    private func switchToBypassMode() {
        action = BoundWindowAction(
            id: action.id,
            action: action.action,
            keybind: triggerKey.union(action.keybind),
            bypassTriggerKey: true
        )
    }

    /// Clears the keybind and switches to standard mode
    private func clearKeybind() {
        action = BoundWindowAction(
            id: action.id,
            action: action.action,
            keybind: [],
            bypassTriggerKey: false
        )
    }

    private func label() -> some View {
        Button {
            isDirectionPickerPresented.toggle()
        } label: {
            HStack(spacing: 8) {
                IconView(action: action.action)

                if let info = action.direction.infoText {
                    Text(action.getActionName())
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .padding(.trailing, 4)
                        .help(Text(info))
                } else {
                    Text(action.getActionName())
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 4)
            .frame(minHeight: 24)
        }
        .buttonStyle(.plain)
        .keybindButtonSurface()
        .help("Customize this keybind's action.")
        .padding(.leading, -4)
    }

    private func keycorderSection() -> some View {
        HStack(spacing: 6) {
            if !action.bypassTriggerKey {
                HStack(spacing: 6) {
                    ForEach(triggerKey.sorted().compactMap(\.modifierSystemImage), id: \.self) { image in
                        Text("\(Image(systemName: image))")
                    }
                }
                .font(.callout)
                .padding(6)
                .frame(height: 27)
                .keybindKeyCap()

                Image(systemName: "plus")
                    .foregroundStyle(.secondary)
            }

            Keycorder($action)
                .opacity(hasDuplicateKeybinds || action.keybind.isEmpty ? 0.5 : 1)
        }
        .contextMenu {
            if action.bypassTriggerKey {
                Button("Link Trigger Key", action: restoreStandardMode)
            } else {
                Button("Unlink Trigger Key", action: switchToBypassMode)
            }

            Button("Clear Keybind", action: clearKeybind)
        }
    }
}

struct KeybindKeyCapStyle: ViewModifier {
    let isHighlighted: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        isHighlighted
                            ? Color.accentColor.opacity(0.14)
                            : Color.secondary.opacity(0.08)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        isHighlighted
                            ? Color.accentColor.opacity(0.32)
                            : Color.secondary.opacity(0.16),
                        lineWidth: 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct KeybindButtonSurfaceStyle: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isPressed
                            ? Color.secondary.opacity(0.14)
                            : isHovering
                            ? Color.secondary.opacity(0.10)
                            : Color.clear
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        Color.secondary.opacity(isHovering || isPressed ? 0.22 : 0),
                        lineWidth: 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .scaleEffect(isPressed ? 0.98 : 1)
            .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: isHovering)
            .animation(reduceMotion ? nil : .snappy(duration: 0.12), value: isPressed)
            .onHover { isHovering = $0 }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

extension View {
    func keybindKeyCap(isHighlighted: Bool = false, cornerRadius: CGFloat = 6) -> some View {
        modifier(KeybindKeyCapStyle(isHighlighted: isHighlighted, cornerRadius: cornerRadius))
    }

    func keybindButtonSurface() -> some View {
        modifier(KeybindButtonSurfaceStyle())
    }
}
