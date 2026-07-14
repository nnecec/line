//
//  URLCommandHandler.swift
//  Line
//
//  Created by nnecec on 06/03/2025.
//

/*
 Line URL Scheme Documentation
 ===========================

 The Line app supports URL scheme commands for window management and automation.
 Base URL format: line://<command>/<parameters>

 Available Commands:
 -----------------

 1. Window Direction Commands:
    Format: line://direction/<direction>
    Examples:
    - line://direction/left       (Move window to left half)
    - line://direction/right      (Move window to right half)
    - line://direction/top        (Move window to top half)
    - line://direction/bottom     (Move window to bottom half)
    - line://direction/maximize   (Maximize window)
    - line://direction/center     (Center window)

 2. Screen Management:
    Format: line://screen/<command>
    Examples:
    - line://screen/next          (Move window to next screen)
    - line://screen/previous      (Move window to previous screen)

 3. Action Commands:
    Format: line://action/<action>
    Examples:
    - line://action/maximize      (Maximize window)
    - line://action/leftHalf      (Move to left half)
    Note: See 'line://list/actions' for all available actions

 4. Keybind Commands:
    Format: line://keybind/<name>
    Examples:
    - line://keybind/myCustomLayout
    Note: See 'line://list/keybinds' for available keybinds

 5. List Commands:
    Format: line://list/<type>
    Types:
    - actions    (List all window actions)
    - keybinds   (List all custom keybinds)
    - all        (List everything)

 Usage Tips:
 ----------
 1. All commands are case-insensitive
 2. Parameters with spaces must be URL encoded
 3. Window commands operate on the frontmost non-terminal window
 4. Use list commands to discover available options

 Examples:
 --------
 # Move current window to right half
 open "line://direction/right"

 # List all available actions
 open "line://list/actions"

 # Execute custom keybind
 open "line://keybind/myLayout"

 Error Examples:
 -------------
 # Invalid command
 open "line://invalid" -> Returns available commands

 # Missing parameter
 open "line://direction" -> Returns available directions

 # Invalid keybind
 open "line://keybind/nonexistent" -> Returns available keybinds
 */

import Defaults
import Foundation
import Scribe
import SwiftUI

enum TargetScreenResolutionPolicy {
    static func choose<Screen>(targetWindowScreen: Screen?, mainScreen: Screen?) -> Screen? {
        targetWindowScreen ?? mainScreen
    }
}

enum URLScreenCommandParser {
    static func screenAction(for rawCommand: String?) -> WindowAction.ScreenSwitchAction? {
        guard let rawCommand else {
            return nil
        }

        switch rawCommand.lowercased() {
        case "next":
            return .next
        case "previous", "prev":
            return .previous
        case "left":
            return .left
        case "right":
            return .right
        case "top", "up":
            return .top
        case "bottom", "down":
            return .bottom
        default:
            return nil
        }
    }
}

/// Handles URL scheme commands for the Line application
@Loggable
final class URLCommandHandler {
    // MARK: - Types

    /// Available URL scheme commands with their descriptions
    enum Command: String, CaseIterable {
        /// Window positioning commands (left, right, top, bottom, etc.)
        case direction
        /// Multi-screen management commands (next, previous)
        case screen
        /// Predefined window actions
        case action
        /// Custom keybind actions
        case keybind
        /// List available commands and options
        case list

        /// Human-readable description of each command type
        var description: String {
            switch self {
            case .direction: "Window direction command"
            case .screen: "Screen management"
            case .action: "Execute predefined window action"
            case .keybind: "Execute custom keybind action"
            case .list: "List available commands"
            }
        }
    }

    enum Scheme {
        static let canonical = "line"
        static let legacy = "loop"
        static let supported: Set<String> = [canonical, legacy]
    }

    static func supports(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return Scheme.supported.contains(scheme)
    }

    static var requiredFormat: String {
        "\(Scheme.canonical)://<command>/<parameters>"
    }

    static func commandURL(_ command: Command, _ parameter: String) -> String {
        "\(Scheme.canonical)://\(command.rawValue)/\(parameter)"
    }

    // MARK: - Properties

    /// Tracks the last active window for context preservation
    private var lastActiveWindow: Window?

    /// Timestamp of last window activation
    private var lastActiveTime: Date?

    /// Whether command output should be collected for the user-facing temporary document.
    private var shouldCollectOutput = false

    /// Buffer for collecting output before writing
    private var outputBuffer: [String] = []

    // MARK: - Output Handling

    /// Writes a titled list of items to output
    /// - Parameters:
    ///   - title: The title for the list
    ///   - items: Array of items to list
    private func appendListOutput(_ title: String, _ items: [String]) {
        let formattedItems = items.map { item in
            if item.hasPrefix("\n") {
                return item.replacingOccurrences(of: "\n", with: "")
            }
            return item
        }

        if shouldCollectOutput {
            outputBuffer.append(title)
            outputBuffer.append(contentsOf: formattedItems)
        }
    }

    /// Returns only stable, non-user-specific command hints for error feedback.
    static func availableCommandHints() -> [String] {
        [
            "line://direction/<direction>",
            "line://screen/<next|previous>",
            "line://action/<action>",
            "line://keybind/<name>",
            "line://list/<actions|keybinds|all>"
        ]
    }

    static func availableDirectionHints() -> [String] {
        WindowDirection.allCases.map { commandURL(.direction, $0.rawValue.lowercased()) }
    }

    static func availableScreenHints() -> [String] {
        [
            commandURL(.screen, "next"),
            commandURL(.screen, "previous")
        ]
    }

    static func availableKeybindHints() -> [String] {
        ["Use line://list/keybinds to view configured keybinds."]
    }

    private func appendAvailableCommandHints() {
        appendListOutput("Available Commands", Self.availableCommandHints())
    }

    private func appendAvailableDirectionHints() {
        appendListOutput("Available Directions", Self.availableDirectionHints())
    }

    private func appendAvailableScreenHints() {
        appendListOutput("Available Screen Commands", Self.availableScreenHints())
    }

    private func appendAvailableKeybindHints() {
        appendListOutput("Available Keybinds", Self.availableKeybindHints())
    }

    /// Flushes the output buffer to a temporary file for user-facing command output.
    /// - Note: Due to limitations with terminal output formatting and the complexity of the list output,
    ///         we use a temporary file to display the formatted list. This allows for proper spacing,
    ///         sections, and formatting that would be difficult to achieve with direct terminal output.
    ///         The file is automatically opened and then deleted after 60 seconds to keep the system clean.
    private func flushOutput() {
        guard shouldCollectOutput,
              !outputBuffer.isEmpty else {
            outputBuffer.removeAll()
            return
        }

        // Create a unique temporary file that will be automatically cleaned up
        let timestamp = Date().timeIntervalSince1970
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("line_output_\(timestamp).txt")

        do {
            try outputBuffer.joined(separator: "\n").write(to: tempFile, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(tempFile)

            // Schedule file deletion after a delay
            // We use a longer delay (60s) to ensure the user has time to read the content
            Task {
                try? await Task.sleep(for: .seconds(60))

                do {
                    try FileManager.default.removeItem(at: tempFile)
                    log.info("Cleaned up temporary URL command output file")
                } catch {
                    log.error("Failed to clean up temporary file: \(ApplicationLogPrivacy.errorDescription(error))")
                }
            }
        } catch {
            log.error("Failed to write output: \(ApplicationLogPrivacy.errorDescription(error))")

            log.info(Self.listOutputFallbackLogDescription(outputBuffer))
        }

        outputBuffer.removeAll()
    }

    // MARK: - Public Methods

    /// Handles incoming URL scheme requests
    /// - Parameter url: The URL to process
    /// - Throws: URLError for invalid URLs or commands
    func handle(_ url: URL) {
        shouldCollectOutput = true
        outputBuffer.removeAll()
        log.info("Received URL command: \(ApplicationLogPrivacy.urlDescription(url))")

        guard url.scheme.map({ Self.Scheme.supported.contains($0.lowercased()) }) == true else {
            appendAvailableCommandHints()
            flushOutput()
            return
        }

        let components = (url.host.map { [$0] } ?? []) + url.pathComponents.filter { $0 != "/" && !$0.isEmpty }

        guard let commandString = components.first,
              let command = Command(rawValue: commandString.lowercased()) else {
            appendAvailableCommandHints()
            flushOutput()
            return
        }

        let parameters = Array(components.dropFirst())
        processCommand(command, parameters)
    }

    // MARK: - Command Processing

    /// Processes a command with its parameters
    /// - Parameters:
    ///   - command: The command to process
    ///   - parameters: Array of command parameters
    private func processCommand(_ command: Command, _ parameters: [String]) {
        log.info(Self.processingLogDescription(command: command, parameters: parameters))

        switch command {
        case .direction: handleDirectionCommand(parameters)
        case .screen: handleScreenCommand(parameters)
        case .action: handleActionCommand(parameters)
        case .keybind: handleKeybindCommand(parameters)
        case .list: handleListCommand(parameters)
        }

        flushOutput()
    }

    static func processingLogDescription(command: Command, parameters: [String]) -> String {
        "Processing \(command.rawValue) command with \(parameters.count) parameter(s)"
    }

    static func listOutputFallbackLogDescription(_ items: [String]) -> String {
        "URL command list output omitted from logs (item count: \(items.count))"
    }

    /// Handles window direction commands
    /// - Parameter parameters: Direction parameters
    private func handleDirectionCommand(_ parameters: [String]) {
        guard let directionStr = parameters.first?.lowercased() else {
            appendAvailableDirectionHints()
            return
        }

        // If this is a list command, redirect to the action handler
        if directionStr == "list" {
            handleListCommand(["actions"])
            return
        }

        // First check if this is a custom action being called via direction
        if directionStr.hasPrefix("custom") || directionStr.hasPrefix("stash") {
            handleActionCommand(parameters)
            return
        }

        let direction: WindowDirection? = WindowDirection.allCases.first { $0.rawValue.lowercased() == directionStr } ?? {
            switch directionStr {
            case "left": return WindowDirection.leftHalf
            case "right": return WindowDirection.rightHalf
            case "top": return WindowDirection.topHalf
            case "bottom": return WindowDirection.bottomHalf
            default:
                let withoutHalf = directionStr.replacingOccurrences(of: "half", with: "")
                return WindowDirection.allCases.first { $0.rawValue.lowercased() == withoutHalf }
            }
        }()

        if let direction {
            executeWindowAction(direction)
        } else {
            appendAvailableDirectionHints()
        }
    }

    /// Executes a window action for a given direction
    /// - Parameter direction: The direction to move/resize the window
    private func executeWindowAction(_ direction: WindowDirection) {
        let allWindows = WindowUtility.windowList()

        let visibleWindows = allWindows.filter { win in
            guard let app = win.nsRunningApplication else {
                return false
            }

            let isLine = app.bundleIdentifier == Bundle.main.bundleIdentifier
            let isRegular = app.activationPolicy == .regular
            let isVisible = !win.isApplicationHidden && !win.minimized

            return !isLine && isRegular && isVisible
        }

        guard let window = findTargetWindow(from: visibleWindows),
              let screen = targetScreen(for: window) else {
            return
        }

        let action = WindowAction(direction)
        activateAndResizeWindow(window, action, screen)
    }

    /// Handles screen management commands
    /// - Parameter parameters: Screen command parameters
    private func handleScreenCommand(_ parameters: [String]) {
        guard let rawCommand = parameters.first?.lowercased(),
              let screenAction = URLScreenCommandParser.screenAction(for: rawCommand) else {
            appendAvailableScreenHints()
            return
        }

        guard let window = try? WindowUtility.frontmostWindow() else {
            return
        }

        moveWindowToScreen(window, screenAction)
    }

    /// Handles predefined window actions
    /// - Parameter parameters: Action parameters
    private func handleActionCommand(_ parameters: [String]) {
        guard let actionStr = parameters.first?.lowercased() else {
            printAvailableActions(includeCustomNames: false)
            return
        }

        // First check for custom actions by name
        let customKeybinds = Defaults[.keybinds].filter { $0.direction.isCustomizable && $0.name != nil }
        if let customAction = customKeybinds.first(where: { ($0.name?.lowercased() ?? "") == actionStr }) {
            // Try multiple methods to get the target window
            let targetWindow = findTargetWindow(from: WindowUtility.windowList().filter { win in
                guard let app = win.nsRunningApplication else { return false }
                return app.activationPolicy == .regular && !win.isApplicationHidden && !win.minimized
            })

            if let window = targetWindow,
               let screen = targetScreen(for: window) {
                activateAndResizeWindow(window, customAction.action, screen)
            }
        } else if actionStr == "list" {
            // For list command, just show the actions without the invalid message
            printAvailableActions(includeCustomNames: true)
        } else if let direction = WindowDirection.allCases.first(where: { $0.rawValue.lowercased() == actionStr }),
                  let window = findTargetWindow(from: WindowUtility.windowList()),
                  let screen = targetScreen(for: window) {
            activateAndResizeWindow(window, direction.toWindowAction(), screen)
        } else {
            printAvailableActions(includeCustomNames: false)
        }
    }

    /// Prints all available window actions in categories
    private func printAvailableActions(includeCustomNames: Bool) {
        var items: [String] = []

        // Get any custom keybinds with names and custom direction
        let customKeybinds = Defaults[.keybinds].filter { $0.direction == .custom && $0.name?.isEmpty == false }
        if includeCustomNames, !customKeybinds.isEmpty {
            items.append("Custom Actions:")
            items.append(contentsOf: customKeybinds.compactMap { keybind in
                guard let name = keybind.name else { return nil }
                return "  • \(Self.commandURL(.action, name.lowercased()))"
            })
            items.append("")
        }

        // Get any stash keybinds with names and custom direction
        let stashKeybinds = Defaults[.keybinds].filter { $0.direction == .stash && $0.name?.isEmpty == false }
        if includeCustomNames, !stashKeybinds.isEmpty {
            items.append("Stash Actions:")
            items.append(contentsOf: stashKeybinds.compactMap { keybind in
                guard let name = keybind.name else { return nil }
                return "  • \(Self.commandURL(.action, name.lowercased()))"
            })
            items.append("")
        }

        let categories: [(String, [WindowDirection])] = [
            ("General Actions", Array(WindowDirection.general.dropFirst(3))), // Drop first 3 actions
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

        for (title, actions) in categories {
            if !actions.isEmpty {
                items.append("\(title):")
                items.append(contentsOf: actions.map { "  • \(Self.commandURL(.action, $0.rawValue.lowercased()))" })
                items.append("")
            }
        }

        // Remove the last empty line if it exists
        if items.last?.isEmpty == true {
            items.removeLast()
        }

        appendListOutput("", items)
    }

    /// Handles custom keybind execution
    /// - Parameter parameters: Keybind parameters
    private func handleKeybindCommand(_ parameters: [String]) {
        guard let keybindName = parameters.first else {
            appendAvailableKeybindHints()
            return
        }

        let keybinds = Defaults[.keybinds]

        if keybindName.lowercased() == "list" {
            appendListOutput("Available Keybinds", keybinds.compactMap(\.name))
            return
        }

        if let keybind = keybinds.first(where: { $0.name?.lowercased() == keybindName.lowercased() }) {
            if let window = WindowUtility.userDefinedTargetWindow(),
               let screen = targetScreen(for: window) {
                Task {
                    _ = try await WindowActionEngine.shared.apply(
                        keybind.action,
                        window: window,
                        screen: screen
                    )
                }
            }
        } else {
            appendAvailableKeybindHints()
        }
    }

    /// Handles list commands for viewing available options
    /// - Parameter parameters: List parameters
    private func handleListCommand(_ parameters: [String]) {
        let type = parameters.first?.lowercased() ?? "all"
        var items: [String] = []

        switch type {
        case "actions":
            items.append("Available Actions:")
            // Get any custom keybinds with names and custom direction
            let customKeybinds = Defaults[.keybinds].filter { $0.direction == .custom && $0.name?.isEmpty == false }
            if !customKeybinds.isEmpty {
                items.append("\nCustom Actions:")
                items.append(contentsOf: customKeybinds.compactMap { keybind in
                    guard let name = keybind.name else { return nil }
                    return "  • \(Self.commandURL(.action, name.lowercased()))"
                })
            }

            // Get any stash keybinds with names and custom direction
            let stashKeybinds = Defaults[.keybinds].filter { $0.direction == .stash && $0.name?.isEmpty == false }
            if !stashKeybinds.isEmpty {
                items.append("\nStash Actions:")
                items.append(contentsOf: stashKeybinds.compactMap { keybind in
                    guard let name = keybind.name else { return nil }
                    return "  • \(Self.commandURL(.action, name.lowercased()))"
                })
            }

            let categories: [(String, [WindowDirection])] = [
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

            for (title, actions) in categories {
                if !actions.isEmpty {
                    items.append("\n\(title):")
                    items.append(contentsOf: actions.map { "  • \(Self.commandURL(.action, $0.rawValue.lowercased()))" })
                }
            }

        case "keybinds":
            items.append("Available Keybinds:")
            items.append(contentsOf: Defaults[.keybinds].compactMap { keybind in
                guard let name = keybind.name else { return nil }
                return "  • \(Self.commandURL(.keybind, name))"
            })

        default:
            items.append("Available Commands:")

            items.append("\nDirection Commands:")
            items.append(contentsOf: WindowDirection.allCases.map { "  • \(Self.commandURL(.direction, $0.rawValue.lowercased()))" })

            items.append("\nScreen Commands:")
            items.append("  • \(Self.commandURL(.screen, "next"))")
            items.append("  • \(Self.commandURL(.screen, "previous"))")

            items.append("\nActions:")
            // Get any custom keybinds with names and custom direction
            let customKeybinds = Defaults[.keybinds].filter { $0.direction == .custom && $0.name?.isEmpty == false }
            if !customKeybinds.isEmpty {
                items.append("\nCustom Actions:")
                items.append(contentsOf: customKeybinds.compactMap { keybind in
                    guard let name = keybind.name else { return nil }
                    return "  • \(Self.commandURL(.action, name.lowercased()))"
                })
            }

            // Get any stash keybinds with names and custom direction
            let stashKeybinds = Defaults[.keybinds].filter { $0.direction == .stash && $0.name?.isEmpty == false }
            if !stashKeybinds.isEmpty {
                items.append("\nStash Actions:")
                items.append(contentsOf: stashKeybinds.compactMap { keybind in
                    guard let name = keybind.name else { return nil }
                    return "  • \(Self.commandURL(.action, name.lowercased()))"
                })
            }

            items.append("\nKeybind Commands:")
            items.append(contentsOf: Defaults[.keybinds].compactMap { keybind in
                guard let name = keybind.name else { return nil }
                return "  • \(Self.commandURL(.keybind, name))"
            })

            items.append("\nList Commands:")
            items.append("  • \(Self.commandURL(.list, "actions"))")
            items.append("  • \(Self.commandURL(.list, "keybinds"))")
            items.append("  • \(Self.commandURL(.list, "all"))")
        }

        appendListOutput(type == "all" ? "All Commands" : items.removeFirst(), Array(items))
    }

    // MARK: - Helper Methods

    private func targetScreen(for window: Window) -> NSScreen? {
        TargetScreenResolutionPolicy.choose(
            targetWindowScreen: ScreenUtility.screenContaining(window),
            mainScreen: NSScreen.main
        )
    }

    /// Finds the most appropriate target window for an action
    /// - Parameter visibleWindows: Array of visible windows to choose from
    /// - Returns: The most appropriate window or nil if none found
    private func findTargetWindow(from visibleWindows: [Window]) -> Window? {
        if let targetWindow = WindowUtility.userDefinedTargetWindow() {
            return targetWindow
        }

        if let lastWindow = lastActiveWindow,
           let app = lastWindow.nsRunningApplication,
           app.bundleIdentifier != Bundle.main.bundleIdentifier,
           !lastWindow.isApplicationHidden, !lastWindow.minimized,
           let lastTime = lastActiveTime,
           lastTime.timeIntervalSinceNow > -5 {
            return lastWindow
        }

        return visibleWindows.first
    }

    /// Activates and resizes a window
    private func activateAndResizeWindow(_ window: Window, _ action: WindowAction, _ screen: NSScreen) {
        lastActiveWindow = window
        lastActiveTime = Date()

        if let app = window.nsRunningApplication {
            app.activate()
        }

        Task {
            try? await Task.sleep(for: .seconds(0.1))

            _ = try await WindowActionEngine.shared.apply(
                action,
                window: window,
                screen: screen
            )
        }
    }

    /// Moves a window to another screen
    private func moveWindowToScreen(_ window: Window, _ action: WindowAction.ScreenSwitchAction) {
        guard let currentScreen = ScreenUtility.screenContaining(window),
              let targetScreen = ScreenSwitchActionPolicy.targetScreen(for: action, from: currentScreen) else {
            return
        }

        let preservedFrameAction = ScreenSwitchActionPolicy.preservingCurrentFrameAction(for: window, on: currentScreen)

        Task {
            _ = try await WindowActionEngine.shared.apply(
                preservedFrameAction.action,
                window: window,
                screen: targetScreen
            )
        }
    }
}
