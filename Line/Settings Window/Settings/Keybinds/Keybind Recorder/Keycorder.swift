//
//  Keycorder.swift
//  Line
//
//  Created by nnecec on 2023-11-10.
//

import Carbon.HIToolbox
import Defaults
import SwiftUI

struct Keycorder: View {
    @EnvironmentObject private var model: KeybindsConfigurationModel
    @Environment(\.appearsActive) private var appearsActive
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let keyLimit: Int = 6

    @Default(.triggerKey) var triggerKey

    @Binding private var boundAction: BoundWindowAction
    @State private var selectionKeybind: Set<CGKeyCode>

    @State private var eventMonitor: LocalEventMonitor?
    @State private var shouldShake: Bool = false
    @State private var shouldError: Bool = false
    @State private var errorMessage: LocalizedStringKey = .init(String("")) // We use Text here for String interpolation with images

    @State private var isHovering: Bool = false
    @State private var isActive: Bool = false

    init(_ boundAction: Binding<BoundWindowAction>) {
        self._boundAction = boundAction
        self._selectionKeybind = State(initialValue: boundAction.wrappedValue.keybind)
    }

    private var validCurrentKeybind: Set<CGKeyCode> {
        get { boundAction.keybind }
        nonmutating set {
            boundAction = BoundWindowAction(
                id: boundAction.id,
                action: boundAction.action,
                keybind: newValue,
                bypassTriggerKey: boundAction.bypassTriggerKey
            )
        }
    }

    private var bypassTriggerKey: Bool {
        get { boundAction.bypassTriggerKey }
        nonmutating set {
            boundAction = BoundWindowAction(
                id: boundAction.id,
                action: boundAction.action,
                keybind: boundAction.keybind,
                bypassTriggerKey: newValue
            )
        }
    }

    var body: some View {
        Button {
            guard !isActive else { return }
            startObservingKeys()
        } label: {
            if selectionKeybind.isEmpty {
                Image(systemName: isActive ? "ellipsis" : "plus")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                    .frame(width: 27, height: 27)
                    .keybindKeyCap(isHighlighted: isActive || isHovering)
                    .frame(minWidth: 40, minHeight: 40)
                    .contentShape(Rectangle())
                    .accessibilityLabel(
                        Text(
                            isActive ? "Listening for keys" : "Record keybind",
                            comment: "Accessibility label for empty keybind recorder control"
                        )
                    )
            } else {
                HStack(spacing: 4) {
                    // First show modifiers in order
                    let sortedKeys = selectionKeybind.sorted { (a: CGKeyCode, b: CGKeyCode) in
                        if a.isModifier, !b.isModifier {
                            return true
                        }
                        if !a.isModifier, b.isModifier {
                            return false
                        }
                        return a < b
                    }

                    ForEach(sortedKeys, id: \.self) { key in
                        if let systemImage = key.modifierSystemImage {
                            Text("\(Image(systemName: systemImage))")
                        } else if let humanReadable = key.humanReadable {
                            Text(humanReadable)
                        }
                    }
                    .frame(width: 27, height: 27)
                    .font(.callout)
                    .keybindKeyCap(isHighlighted: isActive || isHovering)
                }
                .frame(minHeight: 40)
                .contentShape(.rect)
            }
        }
        .modifier(ShakeEffect(shakes: reduceMotion ? 0 : (shouldShake ? 2 : 0)))
        .animation(reduceMotion ? nil : .default, value: shouldShake)
        .popover(isPresented: $shouldError, arrowEdge: .bottom) {
            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: 240)
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .onChange(of: model.currentEventMonitor) {
            if let eventMonitor, model.currentEventMonitor != eventMonitor {
                finishedObservingKeys(wasForced: true)
            }
        }
        .onChange(of: appearsActive) {
            if appearsActive {
                finishedObservingKeys(wasForced: true)
            }
        }
        .onChange(of: validCurrentKeybind) {
            if selectionKeybind != validCurrentKeybind {
                selectionKeybind = validCurrentKeybind
            }
        }
        .buttonStyle(.plain)
        // Don't allow the button to be pressed if more than one keybind is selected in the list
        .allowsHitTesting(model.selectedKeybinds.count <= 1)
        .onDisappear {
            finishedObservingKeys(wasForced: true)
        }
    }

    func startObservingKeys() {
        selectionKeybind = []
        isActive = true

        LineCoordinator.shared.triggerCoordinator.keybindTrigger.stop()

        eventMonitor = LocalEventMonitor(events: [.keyDown, .keyUp]) { event in
            // Handle regular key presses first
            if event.type == .keyDown, !event.isARepeat {
                if event.keyCode == .kVK_Escape {
                    finishedObservingKeys(wasForced: true)
                    return nil
                }

                handleKeyDown(with: event)
            }

            if event.type == .keyUp {
                finishedObservingKeys()
                return nil
            }

            return nil
        }

        eventMonitor!.start()
        model.currentEventMonitor = eventMonitor
    }

    /// Handles key presses and updates the current keybind
    func handleKeyDown(with event: NSEvent) {
        // Get current selected keys that aren't modifiers
        let currentKeys = selectionKeybind + [event.keyCode]
            .map { $0.baseKey(flags: event.modifierFlags) }

        var flags = CGEventFlags(
            cocoaFlags: event.modifierFlags
                .intersection(.deviceIndependentFlagsMask) // Prevents right/left dependence
        )

        if event.keyCode.isFnSpecialKey {
            flags.remove(.maskSecondaryFn)
        }

        let validModifiers = if bypassTriggerKey {
            flags.keyCodes
        } else {
            flags.keyCodes.filter {
                !Defaults[.triggerKey]
                    .map(\.baseModifier)
                    .contains($0)
            }
        }

        let finalKeys = Set(currentKeys + validModifiers)

        shouldError = false

        // Make sure we don't go over the key limit
        guard finalKeys.count <= keyLimit else {
            errorMessage = "You can only use up to \(keyLimit) keys in a keybind."
            shake()
            shouldError = true
            return
        }

        selectionKeybind = finalKeys
    }

    func finishedObservingKeys(wasForced: Bool = false) {
        guard isActive || eventMonitor != nil else { return }

        isActive = false
        let willSet = !wasForced && checkValidKeybindConditions()

        if willSet {
            // Set the valid keybind to the current selected one
            validCurrentKeybind = selectionKeybind
        } else {
            // Set preview keybind back to previous one
            selectionKeybind = validCurrentKeybind
        }

        let monitor = eventMonitor
        monitor?.stop()
        if let monitor, model.currentEventMonitor == monitor {
            model.currentEventMonitor = nil
        }
        eventMonitor = nil

        Task {
            await LineCoordinator.shared.triggerCoordinator.keybindTrigger.start()
        }
    }

    private func checkValidKeybindConditions() -> Bool {
        switch KeybindBindingPolicy.validateRecording(
            selection: selectionKeybind,
            previousSelection: validCurrentKeybind,
            bypassTriggerKey: bypassTriggerKey,
            triggerKey: triggerKey,
            existing: Defaults[.keybinds]
        ) {
        case .unchanged:
            return false
        case .missingModifierInBypass:
            errorMessage = "Please include at least one modifier key."
            shake()
            shouldError = true
            return false
        case let .conflict(displayName):
            errorMessage = "That keybind is already being used by \(displayName)."
            shake()
            shouldError = true
            return false
        case .valid:
            return true
        }
    }

    private func shake() {
        Task {
            shouldShake.toggle()
        }
    }
}
