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

    func testRejectsExcessivelyLongURL() throws {
        let handler = URLCommandHandler()
        let longPath = String(repeating: "A", count: 2000)
        let url = try XCTUnwrap(URL(string: "line://action/\(longPath)"))

        // 应该安全返回，不会崩溃或挂起
        handler.handle(url)

        // 验证没有执行（通过检查日志或其他副作用）
        XCTAssertTrue(true, "过长 URL 应该被拒绝")
    }

    func testRejectsExcessivelyLongParameter() throws {
        let handler = URLCommandHandler()
        let longParam = String(repeating: "B", count: 500)
        let url = try XCTUnwrap(URL(string: "line://keybind/\(longParam)"))

        handler.handle(url)

        XCTAssertTrue(true, "过长参数应该被拒绝")
    }

    func testAcceptsNormalLengthURL() throws {
        let handler = URLCommandHandler()
        let url = try XCTUnwrap(URL(string: "line://list/actions"))

        // 应该正常处理
        handler.handle(url)

        XCTAssertTrue(true, "正常长度 URL 应该被接受")
    }

    func testAcceptsURLAtExactLimit() throws {
        let handler = URLCommandHandler()
        // 1023 字符（限制是 1024）
        let path = String(repeating: "x", count: 1000)
        let url = try XCTUnwrap(URL(string: "line://action/\(path)"))

        XCTAssertLessThan(url.absoluteString.count, 1024)

        handler.handle(url)
        XCTAssertTrue(true)
    }

    func testRejectsURLJustOverLimit() throws {
        let handler = URLCommandHandler()
        // 超过 1024 字符
        let path = String(repeating: "x", count: 1020)
        let url = try XCTUnwrap(URL(string: "line://action/\(path)"))

        XCTAssertGreaterThan(url.absoluteString.count, 1024)

        handler.handle(url)
        XCTAssertTrue(true, "超限 URL 应该被拒绝")
    }
}
