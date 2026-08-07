//
//  URLCommandHandlerTests.swift
//  LineTests
//

@testable import Line
import XCTest

@MainActor
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

    func testScreenHintsIncludeEveryDocumentedDirection() {
        let hints = URLCommandHandler.availableScreenHints()

        for command in ["next", "previous", "left", "right", "top", "bottom"] {
            XCTAssertTrue(hints.contains("line://screen/\(command)"))
        }
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

    func testCatalogAllIncludesEveryCanonicalScreenCommand() {
        let catalog = URLCommandCatalog.build(kind: .all, namedKeybinds: [])
        let joined = catalog.items.joined(separator: "\n")

        for command in URLScreenCommandParser.canonicalCommands {
            XCTAssertTrue(joined.contains("line://screen/\(command)"))
        }
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

final class URLTargetWindowPolicyTests: XCTestCase {
    func testResolutionPriorityAndEligibility() {
        let now = Date(timeIntervalSince1970: 100)
        let resolved = URLTargetWindowPolicy.resolve(
            candidates: ["candidate"],
            userDefined: "user",
            stickyWindow: "sticky",
            stickyTime: now,
            now: now,
            isEligible: { $0 != "user" }
        )

        XCTAssertEqual(resolved, "sticky")
    }

    func testExpiredOrFutureStickyFallsBackToFirstEligibleCandidate() {
        let now = Date(timeIntervalSince1970: 100)

        XCTAssertEqual(
            URLTargetWindowPolicy.resolve(
                candidates: ["ineligible", "candidate"],
                userDefined: nil,
                stickyWindow: "sticky",
                stickyTime: now.addingTimeInterval(-URLTargetWindowPolicy.stickyTTL - 0.01),
                now: now,
                isEligible: { $0 != "ineligible" }
            ),
            "candidate"
        )
        XCTAssertEqual(
            URLTargetWindowPolicy.resolve(
                candidates: ["candidate"],
                userDefined: nil,
                stickyWindow: "sticky",
                stickyTime: now.addingTimeInterval(1),
                now: now,
                isEligible: { _ in true }
            ),
            "candidate"
        )
    }
}

@MainActor
final class URLCommandTargetOrchestratorTests: XCTestCase {
    private final class Target {
        let id: String

        init(_ id: String) {
            self.id = id
        }
    }

    func testActionActivatesAppliesAndReusesSuccessfulStickyTarget() async {
        let first = Target("first")
        let second = Target("second")
        var candidates = [second]
        var userDefined: Target? = first
        var activated: [String] = []
        var applied: [String] = []
        let orchestrator = makeOrchestrator(
            candidates: { candidates },
            userDefined: { userDefined },
            activate: { activated.append($0.id) },
            apply: { _, target, _ in
                applied.append(target.id)
                return true
            }
        )

        let firstResult = await orchestrator.execute(.action(.standard(.maximize)))
        XCTAssertEqual(firstResult, .applied)
        userDefined = nil
        candidates = [second]
        let secondResult = await orchestrator.execute(.action(.standard(.maximize)))
        XCTAssertEqual(secondResult, .applied)

        XCTAssertEqual(activated, ["first", "first"])
        XCTAssertEqual(applied, ["first", "first"])
    }

    func testFailedApplyDoesNotBecomeSticky() async {
        let first = Target("first")
        let second = Target("second")
        var userDefined: Target? = first
        var candidates = [second]
        var shouldFail = true
        var applied: [String] = []
        let orchestrator = makeOrchestrator(
            candidates: { candidates },
            userDefined: { userDefined },
            apply: { _, target, _ in
                if shouldFail {
                    return false
                }
                applied.append(target.id)
                return true
            }
        )

        let failedResult = await orchestrator.execute(.action(.standard(.maximize)))
        XCTAssertEqual(failedResult, .failed)
        shouldFail = false
        userDefined = nil
        candidates = [second]
        let appliedResult = await orchestrator.execute(.action(.standard(.maximize)))
        XCTAssertEqual(appliedResult, .applied)

        XCTAssertEqual(applied, ["second"])
    }

    func testScreenSwitchUsesDestinationWithoutActivation() async {
        let target = Target("target")
        var activationCount = 0
        var appliedScreen: String?
        let orchestrator = makeOrchestrator(
            candidates: { [target] },
            userDefined: { nil },
            activate: { _ in activationCount += 1 },
            destinationScreen: { _, _ in "destination" },
            apply: { _, _, screen in
                appliedScreen = screen
                return true
            }
        )

        let result = await orchestrator.execute(.screenSwitch(.next))
        XCTAssertEqual(result, .applied)
        XCTAssertEqual(activationCount, 0)
        XCTAssertEqual(appliedScreen, "destination")
    }

    func testMissingTargetAndScreenReturnDistinctResults() async {
        let target = Target("target")
        let noTarget = makeOrchestrator(
            candidates: { [] },
            userDefined: { nil }
        )
        let noScreen = makeOrchestrator(
            candidates: { [target] },
            userDefined: { nil },
            screen: { _ in nil },
            mainScreen: { nil }
        )

        let noTargetResult = await noTarget.execute(.action(.standard(.maximize)))
        let noScreenResult = await noScreen.execute(.action(.standard(.maximize)))
        XCTAssertEqual(noTargetResult, .noTarget)
        XCTAssertEqual(noScreenResult, .noScreen)
    }

    func testOverlappingCancellationDoesNotReplaceSuccessfulStickyTarget() async {
        let first = Target("first")
        let second = Target("second")
        let third = Target("third")
        var userDefined: Target? = first
        var candidates = [second]
        var delayCalls = 0
        var applied: [String] = []
        let orchestrator = makeOrchestrator(
            candidates: { candidates },
            userDefined: { userDefined },
            activationDelay: {
                delayCalls += 1
                if delayCalls == 1 {
                    try await Task.sleep(for: .seconds(60))
                }
            },
            apply: { _, target, _ in
                applied.append(target.id)
                return true
            }
        )

        let firstTask = Task {
            await orchestrator.execute(.action(.standard(.maximize)))
        }
        while delayCalls == 0 {
            await Task.yield()
        }

        userDefined = second
        let secondTask = Task {
            await orchestrator.execute(.action(.standard(.maximize)))
        }
        while delayCalls < 2 {
            await Task.yield()
        }
        firstTask.cancel()

        let firstResult = await firstTask.value
        let secondResult = await secondTask.value
        XCTAssertEqual(firstResult, .cancelled)
        XCTAssertEqual(secondResult, .applied)

        userDefined = nil
        candidates = [third]
        let stickyResult = await orchestrator.execute(.action(.standard(.maximize)))
        XCTAssertEqual(stickyResult, .applied)
        XCTAssertEqual(applied, ["second", "second"])
    }

    func testEarlierSlowSuccessCannotOverwriteLaterSuccessfulStickyTarget() async {
        let first = Target("first")
        let second = Target("second")
        let third = Target("third")
        var userDefined: Target? = first
        var candidates = [third]
        var delayCalls = 0
        var releaseFirstDelay: CheckedContinuation<(), Never>?
        var applied: [String] = []
        let orchestrator = makeOrchestrator(
            candidates: { candidates },
            userDefined: { userDefined },
            activationDelay: {
                delayCalls += 1
                if delayCalls == 1 {
                    await withCheckedContinuation { releaseFirstDelay = $0 }
                }
            },
            apply: { _, target, _ in
                applied.append(target.id)
                return true
            }
        )

        let firstTask = Task {
            await orchestrator.execute(.action(.standard(.maximize)))
        }
        while releaseFirstDelay == nil {
            await Task.yield()
        }

        userDefined = second
        let secondResult = await orchestrator.execute(.action(.standard(.maximize)))
        XCTAssertEqual(secondResult, .applied)
        releaseFirstDelay?.resume()
        let firstResult = await firstTask.value
        XCTAssertEqual(firstResult, .applied)

        userDefined = nil
        candidates = [third]
        let stickyResult = await orchestrator.execute(.action(.standard(.maximize)))
        XCTAssertEqual(stickyResult, .applied)
        XCTAssertEqual(applied, ["second", "first", "second"])
    }

    func testLaterFailureStillAllowsEarlierSlowSuccessToBecomeSticky() async {
        let first = Target("first")
        let second = Target("second")
        let third = Target("third")
        var userDefined: Target? = first
        var candidates = [third]
        var delayCalls = 0
        var releaseFirstDelay: CheckedContinuation<(), Never>?
        var attempted: [String] = []
        let orchestrator = makeOrchestrator(
            candidates: { candidates },
            userDefined: { userDefined },
            activationDelay: {
                delayCalls += 1
                if delayCalls == 1 {
                    await withCheckedContinuation { releaseFirstDelay = $0 }
                }
            },
            apply: { _, target, _ in
                attempted.append(target.id)
                return target !== second
            }
        )

        let firstTask = Task {
            await orchestrator.execute(.action(.standard(.maximize)))
        }
        while releaseFirstDelay == nil {
            await Task.yield()
        }

        userDefined = second
        let secondResult = await orchestrator.execute(.action(.standard(.maximize)))
        XCTAssertEqual(secondResult, .failed)
        releaseFirstDelay?.resume()
        let firstResult = await firstTask.value
        XCTAssertEqual(firstResult, .applied)

        userDefined = nil
        candidates = [third]
        let stickyResult = await orchestrator.execute(.action(.standard(.maximize)))
        XCTAssertEqual(stickyResult, .applied)
        XCTAssertEqual(attempted, ["second", "first", "first"])
    }

    private func makeOrchestrator(
        candidates: @escaping @MainActor () -> [Target],
        userDefined: @escaping @MainActor () -> Target?,
        screen: @escaping @MainActor (Target) -> String? = { _ in "current" },
        mainScreen: @escaping @MainActor () -> String? = { "main" },
        activate: @escaping @MainActor (Target) -> () = { _ in },
        destinationScreen: @escaping @MainActor (WindowAction.ScreenSwitchAction, String) -> String? = { _, _ in nil },
        activationDelay: @escaping @MainActor () async throws -> () = {},
        apply: @escaping @MainActor (WindowAction, Target, String) async throws -> Bool = { _, _, _ in true }
    ) -> URLCommandTargetOrchestrator<Target, String> {
        URLCommandTargetOrchestrator(
            dependencies: .init(
                candidates: candidates,
                userDefinedTarget: userDefined,
                isEligible: { _ in true },
                screen: screen,
                mainScreen: mainScreen,
                activate: activate,
                destinationScreen: destinationScreen,
                preservingFrameAction: { _, _ in .standard(.maximize) },
                apply: apply,
                activationDelay: activationDelay,
                now: { Date(timeIntervalSince1970: 100) }
            )
        )
    }
}
