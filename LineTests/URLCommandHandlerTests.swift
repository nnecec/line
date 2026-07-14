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

    func testLegacyLoopSchemeIsStillAccepted() throws {
        let url = try XCTUnwrap(URL(string: "loop://direction/right"))

        XCTAssertTrue(URLCommandHandler.supports(url))
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
}
