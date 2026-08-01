//
//  URLCommandHandlerTests.swift
//  LineTests
//

@testable import Line
import XCTest

final class URLCommandHandlerTests: XCTestCase {
    func testLineSchemeIsAccepted() throws {
        let url = try XCTUnwrap(URL(string: "line://direction/right"))

        XCTAssertTrue(URLCommandHandler.supports(url))
    }

    func testLegacyLoopSchemeIsRejected() throws {
        let url = try XCTUnwrap(URL(string: "loop://direction/right"))

        XCTAssertFalse(URLCommandHandler.supports(url))
    }

    func testOutputFilePolicyCleanupDelayIsAtMostFiveSeconds() {
        XCTAssertLessThanOrEqual(URLCommandHandler.OutputFilePolicy.cleanupDelaySeconds, 5)
        XCTAssertGreaterThan(URLCommandHandler.OutputFilePolicy.cleanupDelaySeconds, 0)
    }

    func testOutputFilePolicyUsesOwnerOnlyPermissions() {
        XCTAssertEqual(URLCommandHandler.OutputFilePolicy.posixPermissions, 0o600)
    }

    func testUnsupportedSchemeIsRejected() throws {
        let url = try XCTUnwrap(URL(string: "https://direction/right"))

        XCTAssertFalse(URLCommandHandler.supports(url))
    }

    func testGeneratedCommandURLsUseCanonicalLineScheme() {
        XCTAssertEqual(URLCommandHandler.commandURL(.action, "maximize"), "line://action/maximize")
        XCTAssertEqual(URLCommandHandler.commandURL(.list, "actions"), "line://list/actions")
        XCTAssertFalse(URLCommandHandler.requiredFormat.contains("loop://"))
    }

    func testProcessingLogDescriptionOmitsParameterValues() {
        let sensitiveName = "Confidential Client Layout"

        let description = URLCommandHandler.processingLogDescription(
            command: .keybind,
            parameters: [sensitiveName, "private-document"]
        )

        XCTAssertEqual(description, "Processing keybind command with 2 parameter(s)")
        XCTAssertFalse(description.contains(sensitiveName))
        XCTAssertFalse(description.contains("private-document"))
    }

    func testListFallbackLogDescriptionOmitsOutputItems() {
        let sensitiveName = "Confidential Client Layout"

        let description = URLCommandHandler.listOutputFallbackLogDescription([
            "Available Keybinds:",
            sensitiveName
        ])

        XCTAssertEqual(description, "URL command list output omitted from logs (item count: 2)")
        XCTAssertFalse(description.contains(sensitiveName))
    }

    func testErrorFeedbackHintsDoNotContainUserConfiguredNames() {
        let sensitiveName = "Confidential Client Layout"
        let hints = URLCommandHandler.availableCommandHints()
            + URLCommandHandler.availableDirectionHints()
            + URLCommandHandler.availableScreenHints()
            + URLCommandHandler.availableKeybindHints()

        XCTAssertFalse(hints.joined(separator: "\n").contains(sensitiveName))
        XCTAssertTrue(hints.contains("Use line://list/keybinds to view configured keybinds."))
    }

    func testTargetWindowScreenWinsOverMainScreen() {
        XCTAssertEqual(
            TargetScreenResolutionPolicy.choose(targetWindowScreen: "target", mainScreen: "main"),
            "target"
        )
    }

    func testMainScreenIsUsedWhenTargetWindowScreenIsMissing() {
        XCTAssertEqual(
            TargetScreenResolutionPolicy.choose(targetWindowScreen: String?.none, mainScreen: "main"),
            "main"
        )
    }

    func testScreenCommandParserAcceptsSupportedCommands() {
        XCTAssertEqual(URLScreenCommandParser.screenAction(for: "next"), .next)
        XCTAssertEqual(URLScreenCommandParser.screenAction(for: "previous"), .previous)
        XCTAssertEqual(URLScreenCommandParser.screenAction(for: "left"), .left)
        XCTAssertEqual(URLScreenCommandParser.screenAction(for: "right"), .right)
        XCTAssertEqual(URLScreenCommandParser.screenAction(for: "top"), .top)
        XCTAssertEqual(URLScreenCommandParser.screenAction(for: "bottom"), .bottom)
    }

    func testScreenCommandParserAcceptsAliases() {
        XCTAssertEqual(URLScreenCommandParser.screenAction(for: "prev"), .previous)
        XCTAssertEqual(URLScreenCommandParser.screenAction(for: "up"), .top)
        XCTAssertEqual(URLScreenCommandParser.screenAction(for: "down"), .bottom)
    }

    func testScreenCommandParserRejectsUnknownCommand() {
        XCTAssertNil(URLScreenCommandParser.screenAction(for: "diagonal"))
        XCTAssertNil(URLScreenCommandParser.screenAction(for: nil))
    }

    // MARK: - URL Length Validation Tests

    func testAcceptsNormalLengthURL() throws {
        let url = try XCTUnwrap(URL(string: "line://list/actions"))

        guard case let .accept(parsed) = URLCommandParser.parse(url) else {
            return XCTFail("normal URL should be accepted")
        }
        XCTAssertEqual(parsed.command, .list)
        XCTAssertEqual(parsed.parameters, ["actions"])
    }

    func testAcceptsURLAtMaximumAllowedLength() throws {
        let prefix = "line://action/"
        let path = makePathWithValidParameters(length: URLCommandParser.maxURLLength - 1 - prefix.count)
        let url = try XCTUnwrap(URL(string: "line://action/\(path)"))

        XCTAssertEqual(url.absoluteString.count, URLCommandParser.maxURLLength - 1)
        guard case .accept = URLCommandParser.parse(url) else {
            return XCTFail("URL below the limit should be accepted")
        }
    }

    func testRejectsURLAtMaximumLength() throws {
        let prefix = "line://action/"
        let path = makePathWithValidParameters(length: URLCommandParser.maxURLLength - prefix.count)
        let url = try XCTUnwrap(URL(string: "line://action/\(path)"))

        XCTAssertEqual(url.absoluteString.count, URLCommandParser.maxURLLength)
        XCTAssertEqual(URLCommandParser.parse(url), .reject(.urlTooLong))
    }

    func testAcceptsParameterAtMaximumLength() throws {
        let parameter = String(repeating: "x", count: URLCommandParser.maxParameterLength)
        let url = try XCTUnwrap(URL(string: "line://keybind/\(parameter)"))

        guard case let .accept(parsed) = URLCommandParser.parse(url) else {
            return XCTFail("parameter at the limit should be accepted")
        }
        XCTAssertEqual(parsed.parameters, [parameter])
    }

    func testRejectsParameterAboveMaximumLength() throws {
        let parameter = String(repeating: "x", count: URLCommandParser.maxParameterLength + 1)
        let url = try XCTUnwrap(URL(string: "line://keybind/\(parameter)"))

        XCTAssertEqual(URLCommandParser.parse(url), .reject(.parameterTooLong))
    }

    // MARK: - URLCommandParser

    func testParserAcceptsDirectionCommand() throws {
        let url = try XCTUnwrap(URL(string: "line://direction/left"))
        guard case let .accept(parsed) = URLCommandParser.parse(url) else {
            return XCTFail("expected accept")
        }
        XCTAssertEqual(parsed.command, .direction)
        XCTAssertEqual(parsed.parameters, ["left"])
    }

    func testParserRejectsUnsupportedScheme() throws {
        let url = try XCTUnwrap(URL(string: "loop://direction/left"))
        XCTAssertEqual(URLCommandParser.parse(url), .reject(.unsupportedScheme))
    }

    func testParserRejectsUnknownCommand() throws {
        let url = try XCTUnwrap(URL(string: "line://fly/away"))
        XCTAssertEqual(URLCommandParser.parse(url), .reject(.unknownCommand))
    }

    // MARK: - URLDirectionResolver

    func testDirectionAliasesMapToHalves() {
        XCTAssertEqual(URLDirectionResolver.direction(for: "left"), .leftHalf)
        XCTAssertEqual(URLDirectionResolver.direction(for: "right"), .rightHalf)
        XCTAssertEqual(URLDirectionResolver.direction(for: "top"), .topHalf)
        XCTAssertEqual(URLDirectionResolver.direction(for: "bottom"), .bottomHalf)
    }

    func testDirectionExactRawValues() {
        XCTAssertEqual(URLDirectionResolver.direction(for: "lefthalf"), .leftHalf)
        XCTAssertEqual(URLDirectionResolver.direction(for: "maximize"), .maximize)
    }

    func testDirectionRejectsUnknown() {
        XCTAssertNil(URLDirectionResolver.direction(for: "diagonal"))
        XCTAssertNil(URLDirectionResolver.direction(for: nil))
    }

    func testPredefinedActionMatchesRawValueOnly() {
        XCTAssertEqual(URLDirectionResolver.predefinedAction(for: "maximize"), .maximize)
        XCTAssertNil(URLDirectionResolver.predefinedAction(for: "left")) // alias only on direction path
    }

    // MARK: - URLCommandCatalog

    func testCatalogListKindParsing() {
        XCTAssertEqual(URLCommandCatalog.listKind(from: "actions"), .actions)
        XCTAssertEqual(URLCommandCatalog.listKind(from: "keybinds"), .keybinds)
        XCTAssertEqual(URLCommandCatalog.listKind(from: nil), .all)
        XCTAssertEqual(URLCommandCatalog.listKind(from: "unknown"), .all)
    }

    func testCatalogActionsIncludesPredefinedSections() {
        let catalog = URLCommandCatalog.build(kind: .actions, namedKeybinds: [])
        let joined = catalog.items.joined(separator: "\n")
        XCTAssertTrue(joined.contains("Available Actions:"))
        XCTAssertTrue(joined.contains("Halves:"))
        XCTAssertTrue(joined.lowercased().contains("line://action/lefthalf"))
    }

    func testCatalogNamedCustomAndStashSections() {
        let binds = [
            URLCommandCatalog.NamedKeybind(name: "My Layout", isCustom: true, isStash: false),
            URLCommandCatalog.NamedKeybind(name: "Edge Stash", isCustom: false, isStash: true)
        ]
        let catalog = URLCommandCatalog.build(kind: .actions, namedKeybinds: binds)
        let joined = catalog.items.joined(separator: "\n")
        XCTAssertTrue(joined.contains("Custom Actions:"))
        XCTAssertTrue(joined.lowercased().contains("my layout"))
        XCTAssertTrue(joined.contains("Stash Actions:"))
    }

    func testCatalogKeybindsListsNames() {
        let binds = [URLCommandCatalog.NamedKeybind(name: "Focus Work", isCustom: false, isStash: false)]
        let catalog = URLCommandCatalog.build(kind: .keybinds, namedKeybinds: binds)
        XCTAssertEqual(catalog.items.first, "Available Keybinds:")
        XCTAssertTrue(catalog.items.contains { $0.contains("Focus Work") })
    }

    func testPrintActionItemsOmitsCustomWhenDisabled() {
        let binds = [URLCommandCatalog.NamedKeybind(name: "Secret", isCustom: true, isStash: false)]
        let without = URLCommandCatalog.printActionItems(namedKeybinds: binds, includeCustomNames: false)
        XCTAssertFalse(without.joined(separator: "\n").contains("Secret"))
        let with = URLCommandCatalog.printActionItems(namedKeybinds: binds, includeCustomNames: true)
        XCTAssertTrue(with.joined(separator: "\n").contains("Custom Actions:"))
    }

    private func makePathWithValidParameters(length: Int) -> String {
        var remainingLength = length
        var parameters: [String] = []

        while remainingLength > 0 {
            if !parameters.isEmpty {
                remainingLength -= 1 // Path separator
            }

            let parameterLength = min(URLCommandParser.maxParameterLength, remainingLength)
            parameters.append(String(repeating: "x", count: parameterLength))
            remainingLength -= parameterLength
        }

        return parameters.joined(separator: "/")
    }
}
