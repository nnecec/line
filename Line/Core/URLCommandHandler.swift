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

 Security Limits:
 ---------------
 - Maximum URL length: 1024 characters
 - Maximum individual parameter length: 256 characters
 - URLs exceeding these limits are silently rejected

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
    static let canonicalCommands = ["next", "previous", "left", "right", "top", "bottom"]

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
@MainActor
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
        /// Only the registered `line://` scheme is accepted (Info.plist + docs).
        /// Legacy `loop://` is intentionally rejected to avoid conflict with Loop.
        static let supported: Set<String> = [canonical]
    }

    /// Policy for temporary list-output files written by URL commands.
    enum OutputFilePolicy {
        /// Delay before deleting the temp file after opening it (seconds).
        static let cleanupDelaySeconds: TimeInterval = 5
        /// Owner-read/write only POSIX permissions.
        static let posixPermissions: Int = 0o600
    }

    nonisolated static func supports(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return Scheme.supported.contains(scheme)
    }

    nonisolated static var requiredFormat: String {
        "\(Scheme.canonical)://<command>/<parameters>"
    }

    nonisolated static func commandURL(_ command: Command, _ parameter: String) -> String {
        "\(Scheme.canonical)://\(command.rawValue)/\(parameter)"
    }

    // MARK: - Properties

    private lazy var targetOrchestrator = makeTargetOrchestrator()

    /// Whether command output should be collected for the user-facing temporary document.
    private var shouldCollectOutput = false

    /// Buffer for collecting output before writing
    private var outputBuffer: [String] = []

    /// Temp list-output files awaiting delayed cleanup.
    private var pendingOutputFiles: [URL] = []

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
    nonisolated static func availableCommandHints() -> [String] {
        [
            "line://direction/<direction>",
            "line://screen/<next|previous|left|right|top|bottom>",
            "line://action/<action>",
            "line://keybind/<name>",
            "line://list/<actions|keybinds|all>"
        ]
    }

    nonisolated static func availableDirectionHints() -> [String] {
        WindowDirection.allCases.map { commandURL(.direction, $0.rawValue.lowercased()) }
    }

    nonisolated static func availableScreenHints() -> [String] {
        URLScreenCommandParser.canonicalCommands.map { commandURL(.screen, $0) }
    }

    nonisolated static func availableKeybindHints() -> [String] {
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
    ///         The file is owner-only (`0o600`) and deleted after a short delay.
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
            try FileManager.default.setAttributes(
                [.posixPermissions: OutputFilePolicy.posixPermissions],
                ofItemAtPath: tempFile.path
            )
            pendingOutputFiles.append(tempFile)
            NSWorkspace.shared.open(tempFile)

            // Short delay so the viewer can open the file before deletion.
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(OutputFilePolicy.cleanupDelaySeconds))
                self?.removePendingOutputFile(tempFile)
            }
        } catch {
            log.error("Failed to write output: \(ApplicationLogPrivacy.errorDescription(error))")

            log.info(Self.listOutputFallbackLogDescription(outputBuffer))
        }

        outputBuffer.removeAll()
    }

    /// Removes a pending temp output file and drops it from the tracking list.
    private func removePendingOutputFile(_ file: URL) {
        pendingOutputFiles.removeAll { $0 == file }
        do {
            try FileManager.default.removeItem(at: file)
            log.info("Cleaned up temporary URL command output file")
        } catch {
            // Already deleted or never fully written — non-fatal.
            log.error("Failed to clean up temporary file: \(ApplicationLogPrivacy.errorDescription(error))")
        }
    }

    /// Best-effort cleanup of any remaining temp list-output files (e.g. app termination).
    func cleanupPendingOutputFiles() {
        let files = pendingOutputFiles
        pendingOutputFiles.removeAll()
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    // MARK: - Public Methods

    /// Handles incoming URL scheme requests
    /// - Parameter url: The URL to process
    /// - Throws: URLError for invalid URLs or commands
    func handle(_ url: URL) {
        shouldCollectOutput = true
        outputBuffer.removeAll()
        log.info("Received URL command: \(ApplicationLogPrivacy.urlDescription(url))")

        switch URLCommandParser.parse(url) {
        case let .accept(parsed):
            processCommand(parsed.command, parsed.parameters)
        case .reject(.unsupportedScheme), .reject(.unknownCommand):
            appendAvailableCommandHints()
            flushOutput()
        case .reject(.urlTooLong):
            log.error("URL command rejected: exceeds maximum length of \(URLCommandParser.maxURLLength) characters")
        case .reject(.parameterTooLong):
            log.error("URL command rejected: parameter exceeds maximum length of \(URLCommandParser.maxParameterLength) characters")
        }
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

    nonisolated static func processingLogDescription(command: Command, parameters: [String]) -> String {
        "Processing \(command.rawValue) command with \(parameters.count) parameter(s)"
    }

    nonisolated static func listOutputFallbackLogDescription(_ items: [String]) -> String {
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

        let direction = URLDirectionResolver.direction(for: directionStr)

        if let direction {
            executeWindowAction(direction)
        } else {
            appendAvailableDirectionHints()
        }
    }

    /// Executes a window action for a given direction
    /// - Parameter direction: The direction to move/resize the window
    private func executeWindowAction(_ direction: WindowDirection) {
        executeTargetedCommand(.action(WindowAction(direction)))
    }

    /// Handles screen management commands
    /// - Parameter parameters: Screen command parameters
    private func handleScreenCommand(_ parameters: [String]) {
        guard let rawCommand = parameters.first?.lowercased(),
              let screenAction = URLScreenCommandParser.screenAction(for: rawCommand) else {
            appendAvailableScreenHints()
            return
        }

        executeTargetedCommand(.screenSwitch(screenAction))
    }

    /// Handles predefined window actions
    /// - Parameter parameters: Action parameters
    private func handleActionCommand(_ parameters: [String]) {
        guard let actionStr = parameters.first?.lowercased() else {
            printAvailableActions(includeCustomNames: false)
            return
        }

        // First check for custom / stash actions by name
        let customKeybinds = Defaults[.keybinds].filter { $0.direction.isCustomizable && $0.name != nil }
        if let customAction = customKeybinds.first(where: { ($0.name?.lowercased() ?? "") == actionStr }) {
            executeTargetedCommand(.action(customAction.action))
        } else if actionStr == "list" {
            printAvailableActions(includeCustomNames: true)
        } else if let direction = URLDirectionResolver.predefinedAction(for: actionStr) {
            executeTargetedCommand(.action(direction.toWindowAction()))
        } else {
            printAvailableActions(includeCustomNames: false)
        }
    }

    /// Prints all available window actions in categories
    private func printAvailableActions(includeCustomNames: Bool) {
        let items = URLCommandCatalog.printActionItems(
            namedKeybinds: namedKeybindsSnapshot(),
            includeCustomNames: includeCustomNames
        )
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
            executeTargetedCommand(.action(keybind.action))
        } else {
            appendAvailableKeybindHints()
        }
    }

    /// Handles list commands for viewing available options
    /// - Parameter parameters: List parameters
    private func handleListCommand(_ parameters: [String]) {
        let kind = URLCommandCatalog.listKind(from: parameters.first)
        let catalog = URLCommandCatalog.build(
            kind: kind,
            namedKeybinds: namedKeybindsSnapshot()
        )
        appendListOutput(catalog.title, catalog.items)
    }

    // MARK: - Helper Methods

    private func namedKeybindsSnapshot() -> [URLCommandCatalog.NamedKeybind] {
        Defaults[.keybinds].compactMap { keybind in
            guard let name = keybind.name, !name.isEmpty else { return nil }
            return URLCommandCatalog.NamedKeybind(
                name: name,
                isCustom: keybind.direction == .custom,
                isStash: keybind.direction == .stash
            )
        }
    }

    private func executeTargetedCommand(_ request: URLCommandTargetOrchestrator<Window, NSScreen>.Request) {
        Task { [weak self] in
            guard let self else { return }
            let result = await targetOrchestrator.execute(request)
            guard result != .applied else { return }
            log.error("URL command was not applied (result: \(String(describing: result)))")
        }
    }

    private func makeTargetOrchestrator() -> URLCommandTargetOrchestrator<Window, NSScreen> {
        let lineBundleID = Bundle.main.bundleIdentifier
        return URLCommandTargetOrchestrator(
            dependencies: .init(
                candidates: { WindowUtility.windowList() },
                userDefinedTarget: { WindowUtility.userDefinedTargetWindow() },
                isEligible: {
                    URLTargetWindowPolicy.isEligibleCandidate($0, lineBundleID: lineBundleID)
                },
                screen: { ScreenUtility.screenContaining($0) },
                mainScreen: { NSScreen.main },
                activate: { $0.nsRunningApplication?.activate() },
                destinationScreen: {
                    ScreenSwitchActionPolicy.targetScreen(for: $0, from: $1)
                },
                preservingFrameAction: {
                    ScreenSwitchActionPolicy.preservingCurrentFrameAction(for: $0, on: $1).action
                },
                apply: {
                    try await WindowActionEngine.shared.apply($0, window: $1, screen: $2).success
                },
                activationDelay: {
                    try await Task.sleep(for: .seconds(0.1))
                },
                now: { Date() }
            )
        )
    }
}
