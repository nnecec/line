//
//  SettingsSharedControls.swift
//  Line
//
//  Shared chrome for settings panes: badges, empty states, outlines, toolbars.
//

import SwiftUI

// MARK: - Status Badge

struct SettingsStatusBadge: View {
    enum Style {
        case neutral
        case accent
        case success
        case warning
        case destructive
    }

    let title: LocalizedStringKey
    let systemImage: String
    var style: Style = .neutral

    /// Backward-compatible initializer used by existing call sites.
    init(
        title: LocalizedStringKey,
        systemImage: String,
        isProminent: Bool = false
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = isProminent ? .accent : .neutral
    }

    init(
        title: LocalizedStringKey,
        systemImage: String,
        style: Style
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
    }

    private static let cornerRadius: CGFloat = 7

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(background, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .strokeBorder(border, lineWidth: 0.75)
            }
            .accessibilityElement(children: .combine)
    }

    private var foreground: Color {
        switch style {
        case .neutral: .secondary
        case .accent: .accentColor
        case .success: Color(nsColor: .systemGreen)
        case .warning: Color(nsColor: .systemOrange)
        case .destructive: Color(nsColor: .systemRed)
        }
    }

    private var background: Color {
        switch style {
        case .neutral: Color.secondary.opacity(0.09)
        case .accent: Color.accentColor.opacity(0.11)
        case .success: Color(nsColor: .systemGreen).opacity(0.11)
        case .warning: Color(nsColor: .systemOrange).opacity(0.11)
        case .destructive: Color(nsColor: .systemRed).opacity(0.11)
        }
    }

    private var border: Color {
        switch style {
        case .neutral: Color.secondary.opacity(0.16)
        case .accent: Color.accentColor.opacity(0.24)
        case .success: Color(nsColor: .systemGreen).opacity(0.24)
        case .warning: Color(nsColor: .systemOrange).opacity(0.24)
        case .destructive: Color(nsColor: .systemRed).opacity(0.24)
        }
    }
}

// MARK: - Empty State

struct SettingsEmptyState: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> ())?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 54, height: 54)
                .background(
                    Color.secondary.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.11), lineWidth: 0.75)
                }

            VStack(spacing: 5) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 300)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 188)
        .padding(.horizontal, 22)
        .padding(.vertical, 26)
    }
}

// MARK: - List Toolbar

struct SettingsListToolbar<Trailing: View>: View {
    let onAdd: () -> ()
    var addHelp: LocalizedStringKey = "Add"
    var addKeyboardShortcut: KeyEquivalent?
    let onRemove: () -> ()
    var removeHelp: LocalizedStringKey = "Remove"
    var canRemove: Bool = true
    @ViewBuilder var trailing: () -> Trailing

    init(
        onAdd: @escaping () -> (),
        addHelp: LocalizedStringKey = "Add",
        addKeyboardShortcut: KeyEquivalent? = nil,
        onRemove: @escaping () -> (),
        removeHelp: LocalizedStringKey = "Remove",
        canRemove: Bool = true,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.onAdd = onAdd
        self.addHelp = addHelp
        self.addKeyboardShortcut = addKeyboardShortcut
        self.onRemove = onRemove
        self.removeHelp = removeHelp
        self.canRemove = canRemove
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onAdd) {
                Label("Add", systemImage: "plus")
            }
            .help(addHelp)
            .modifier(OptionalKeyboardShortcut(shortcut: addKeyboardShortcut))

            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "minus")
            }
            .disabled(!canRemove)
            .keyboardShortcut(.delete)
            .help(removeHelp)

            Spacer(minLength: 0)

            trailing()
        }
        .buttonStyle(.borderless)
        .controlSize(.large)
    }
}

private struct OptionalKeyboardShortcut: ViewModifier {
    let shortcut: KeyEquivalent?

    func body(content: Content) -> some View {
        if let shortcut {
            content.keyboardShortcut(shortcut, modifiers: .command)
        } else {
            content
        }
    }
}

// MARK: - Image Outline

private enum SettingsOutlineColor {
    /// Soft edge that stays neutral without pure black/white hard edges.
    static func color(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.primary.opacity(0.14)
            : Color.primary.opacity(0.10)
    }
}

struct SettingsRoundedImageOutline: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(SettingsOutlineColor.color(for: colorScheme), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

struct SettingsCircleImageOutline: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .overlay {
                Circle()
                    .strokeBorder(SettingsOutlineColor.color(for: colorScheme), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    /// Outline for rounded-rectangle images with a soft primary-tinted edge.
    func settingsImageOutline(cornerRadius: CGFloat = 0) -> some View {
        modifier(SettingsRoundedImageOutline(cornerRadius: cornerRadius))
    }

    /// Outline for circular avatars with a soft primary-tinted edge.
    func settingsCircleImageOutline() -> some View {
        modifier(SettingsCircleImageOutline())
    }
}
