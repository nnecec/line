//
//  URLCommandCatalog.swift
//  Line
//
//  Builds user-facing list output for URL scheme discovery commands.
//

import Foundation

enum URLCommandCatalog {
    enum ListKind: String {
        case actions
        case keybinds
        case all
    }

    struct NamedKeybind: Equatable {
        let name: String
        let isCustom: Bool
        let isStash: Bool
    }

    private static let directionCategories: [(String, [WindowDirection])] = [
        ("General Actions", Array(WindowDirection.general.dropFirst(3))),
        ("Halves", WindowDirection.halves),
        ("Quarters", WindowDirection.quarters),
        ("Horizontal Thirds", WindowDirection.horizontalThirds),
        ("Vertical Thirds", WindowDirection.verticalThirds),
        ("Screen Switching", WindowDirection.screenSwitching),
        ("Size Adjustment", WindowDirection.sizeAdjustment),
        ("Shrink", WindowDirection.shrink),
        ("Grow", WindowDirection.grow),
        ("Move", WindowDirection.move),
        ("Other", WindowDirection.more)
    ]

    static func listKind(from raw: String?) -> ListKind {
        switch raw?.lowercased() {
        case "actions": .actions
        case "keybinds": .keybinds
        default: .all
        }
    }

    /// Build list output. Returns a title for `appendListOutput` and body items.
    static func build(
        kind: ListKind,
        namedKeybinds: [NamedKeybind]
    ) -> (title: String, items: [String]) {
        switch kind {
        case .actions:
            var items = ["Available Actions:"]
            items.append(contentsOf: namedSections(namedKeybinds: namedKeybinds, style: .listActions))
            items.append(contentsOf: predefinedActionSections(style: .listActions))
            return ("", items)

        case .keybinds:
            var items = ["Available Keybinds:"]
            items.append(contentsOf: namedKeybinds.map {
                "  • \(URLCommandHandler.commandURL(.keybind, $0.name))"
            })
            return ("", items)

        case .all:
            var items = ["Available Commands:"]

            items.append("\nDirection Commands:")
            items.append(contentsOf: WindowDirection.allCases.map {
                "  • \(URLCommandHandler.commandURL(.direction, $0.rawValue.lowercased()))"
            })

            items.append("\nScreen Commands:")
            items.append(contentsOf: URLScreenCommandParser.canonicalCommands.map {
                "  • \(URLCommandHandler.commandURL(.screen, $0))"
            })

            items.append("\nActions:")
            items.append(contentsOf: namedSections(namedKeybinds: namedKeybinds, style: .listActions))
            items.append(contentsOf: predefinedActionSections(style: .listActions))

            items.append("\nKeybind Commands:")
            items.append(contentsOf: namedKeybinds.map {
                "  • \(URLCommandHandler.commandURL(.keybind, $0.name))"
            })

            items.append("\nList Commands:")
            items.append("  • \(URLCommandHandler.commandURL(.list, "actions"))")
            items.append("  • \(URLCommandHandler.commandURL(.list, "keybinds"))")
            items.append("  • \(URLCommandHandler.commandURL(.list, "all"))")

            return ("All Commands", items)
        }
    }

    /// Action listing for invalid-action error feedback (`printAvailableActions`).
    static func printActionItems(
        namedKeybinds: [NamedKeybind],
        includeCustomNames: Bool
    ) -> [String] {
        var items: [String] = []
        if includeCustomNames {
            items.append(contentsOf: namedSections(namedKeybinds: namedKeybinds, style: .printActions))
        }
        items.append(contentsOf: predefinedActionSections(style: .printActions))
        if items.last?.isEmpty == true {
            items.removeLast()
        }
        return items
    }

    // MARK: - Private

    private enum SectionStyle {
        /// list/actions and list/all action blocks use leading newlines on section headers.
        case listActions
        /// printAvailableActions uses plain headers and trailing blank lines.
        case printActions
    }

    private static func namedSections(
        namedKeybinds: [NamedKeybind],
        style: SectionStyle
    ) -> [String] {
        var items: [String] = []
        let customs = namedKeybinds.filter(\.isCustom)
        let stashes = namedKeybinds.filter(\.isStash)

        switch style {
        case .listActions:
            if !customs.isEmpty {
                items.append("\nCustom Actions:")
                items.append(contentsOf: customs.map {
                    "  • \(URLCommandHandler.commandURL(.action, $0.name.lowercased()))"
                })
            }
            if !stashes.isEmpty {
                items.append("\nStash Actions:")
                items.append(contentsOf: stashes.map {
                    "  • \(URLCommandHandler.commandURL(.action, $0.name.lowercased()))"
                })
            }
        case .printActions:
            if !customs.isEmpty {
                items.append("Custom Actions:")
                items.append(contentsOf: customs.map {
                    "  • \(URLCommandHandler.commandURL(.action, $0.name.lowercased()))"
                })
                items.append("")
            }
            if !stashes.isEmpty {
                items.append("Stash Actions:")
                items.append(contentsOf: stashes.map {
                    "  • \(URLCommandHandler.commandURL(.action, $0.name.lowercased()))"
                })
                items.append("")
            }
        }
        return items
    }

    private static func predefinedActionSections(style: SectionStyle) -> [String] {
        var items: [String] = []
        for (title, actions) in directionCategories where !actions.isEmpty {
            switch style {
            case .listActions:
                items.append("\n\(title):")
                items.append(contentsOf: actions.map {
                    "  • \(URLCommandHandler.commandURL(.action, $0.rawValue.lowercased()))"
                })
            case .printActions:
                items.append("\(title):")
                items.append(contentsOf: actions.map {
                    "  • \(URLCommandHandler.commandURL(.action, $0.rawValue.lowercased()))"
                })
                items.append("")
            }
        }
        return items
    }
}
