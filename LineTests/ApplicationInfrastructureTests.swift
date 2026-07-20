//
//  ApplicationInfrastructureTests.swift
//  LineTests
//

import Combine
@testable import Line
import XCTest

@MainActor
final class SparkleUpdaterTests: XCTestCase {
    func testInfoPlistDoesNotEnableSandboxOnlyInstallerLauncherService() {
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "SUEnableInstallerLauncherService"))
    }

    func testSuccessfulStartPublishesReadyStateAndServiceAvailability() {
        let service = FakeSparkleUpdateService(canCheckForUpdates: true)
        let updater = SparkleUpdater(service: service, isUpdaterEnabled: true)

        updater.start()

        XCTAssertEqual(updater.state, .ready)
        XCTAssertTrue(updater.canCheckForUpdates)
        XCTAssertEqual(service.startCallCount, 1)
    }

    func testFailedStartPublishesRecoverableUnavailableState() {
        let service = FakeSparkleUpdateService(
            canCheckForUpdates: true,
            startError: FakeSparkleUpdateService.StartError.requested
        )
        let updater = SparkleUpdater(service: service, isUpdaterEnabled: true)

        updater.start()

        XCTAssertEqual(updater.state, .unavailable)
        XCTAssertFalse(updater.canCheckForUpdates)
        XCTAssertTrue(updater.canRetryStart)
    }

    func testRetryCanRecoverFromAnEarlierStartFailure() {
        let service = FakeSparkleUpdateService(
            canCheckForUpdates: true,
            startError: FakeSparkleUpdateService.StartError.requested
        )
        let updater = SparkleUpdater(service: service, isUpdaterEnabled: true)
        updater.start()
        service.startError = nil

        updater.retryStart()

        XCTAssertEqual(updater.state, .ready)
        XCTAssertTrue(updater.canCheckForUpdates)
        XCTAssertEqual(service.startCallCount, 2)
    }
}

final class ApplicationLoggingTests: XCTestCase {
    func testProductionLoggingOnlyEmitsWarningsAndErrorsByDefault() {
        XCTAssertEqual(ApplicationLoggingPolicy.minimumLevel(for: .production), .warning)
    }

    func testDebugLoggingIncludesDebugLevel() {
        XCTAssertEqual(ApplicationLoggingPolicy.minimumLevel(for: .debug), .debug)
    }

    func testWindowDescriptionOmitsApplicationAndTitleButKeepsDiagnosticIdentity() {
        let sensitiveTitle = "Confidential acquisition plan"
        let sensitiveApplication = "com.example.Editor"
        let description = ApplicationLogPrivacy.windowDescription(id: 42)

        XCTAssertEqual(description, "Window(id: 42)")
        XCTAssertFalse(description.contains(sensitiveApplication))
        XCTAssertFalse(description.contains(sensitiveTitle))
    }

    func testURLDescriptionOmitsCredentialsPortPathQueryAndFragment() throws {
        let url = try XCTUnwrap(URL(string: "line://alice:password@execute:8443/private/document?token=secret#selection"))

        let description = ApplicationLogPrivacy.urlDescription(url)

        XCTAssertEqual(description, "line:<redacted>")
        XCTAssertFalse(description.contains("execute"))
        XCTAssertFalse(description.contains("alice"))
        XCTAssertFalse(description.contains("password"))
        XCTAssertFalse(description.contains("8443"))
        XCTAssertFalse(description.contains("private"))
        XCTAssertFalse(description.contains("token"))
        XCTAssertFalse(description.contains("secret"))
        XCTAssertFalse(description.contains("selection"))
    }

    func testFileDescriptionOmitsEveryPathComponent() {
        let url = URL(fileURLWithPath: "/Users/alice/Clients/Secret/plan.line")

        let description = ApplicationLogPrivacy.fileDescription(url)

        XCTAssertEqual(description, "<redacted-path>")
        XCTAssertFalse(description.contains("alice"))
        XCTAssertFalse(description.contains("plan.line"))
    }

    func testErrorDescriptionOmitsLocalizedDetails() {
        let error = NSError(
            domain: "LineTests",
            code: 7,
            userInfo: [NSLocalizedDescriptionKey: "Could not open /Users/alice/Secret.plan"]
        )

        let description = ApplicationLogPrivacy.errorDescription(error)

        XCTAssertFalse(description.contains("alice"))
        XCTAssertFalse(description.contains("Secret.plan"))
        XCTAssertTrue(description.contains("NSError"))
    }
}

final class ProjectLinksTests: XCTestCase {
    func testRepositoryURLUsesCanonicalProjectLocation() {
        XCTAssertEqual(ProjectLinks.repositoryURL?.absoluteString, "https://github.com/nnecec/Line")
    }

    func testIssuesURLUsesCanonicalProjectLocation() {
        XCTAssertEqual(ProjectLinks.issuesURL?.absoluteString, "https://github.com/nnecec/Line/issues")
    }

    func testURLSchemeDocsURLUsesCanonicalProjectLocation() {
        XCTAssertEqual(
            ProjectLinks.urlSchemeDocsURL?.absoluteString,
            "https://github.com/nnecec/Line/blob/main/docs/URL_SCHEME.md"
        )
    }

    func testSparkleFeedUsesCanonicalRepositoryCase() {
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            "https://raw.githubusercontent.com/nnecec/Line/main/appcast.xml"
        )
    }
}

@MainActor
private final class FakeSparkleUpdateService: SparkleUpdateService {
    enum StartError: Error {
        case requested
    }

    var canCheckForUpdates: Bool
    var canCheckForUpdatesPublisher: AnyPublisher<Bool, Never> {
        Just(canCheckForUpdates).eraseToAnyPublisher()
    }

    var automaticallyChecksForUpdates = true
    var startError: Error?
    private(set) var startCallCount = 0

    init(canCheckForUpdates: Bool, startError: Error? = nil) {
        self.canCheckForUpdates = canCheckForUpdates
        self.startError = startError
    }

    func start() throws {
        startCallCount += 1
        if let startError {
            throw startError
        }
    }

    func checkForUpdates() {}
}
