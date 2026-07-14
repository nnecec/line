//
//  SparkleUpdater.swift
//  Line
//

import Combine
import Scribe
import Sparkle

@MainActor
protocol SparkleUpdateService: AnyObject {
    var canCheckForUpdates: Bool { get }
    var canCheckForUpdatesPublisher: AnyPublisher<Bool, Never> { get }
    var automaticallyChecksForUpdates: Bool { get set }

    func start() throws
    func checkForUpdates()
}

@MainActor
private final class StandardSparkleUpdateService: SparkleUpdateService {
    private let controller = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }

    var canCheckForUpdatesPublisher: AnyPublisher<Bool, Never> {
        controller.updater.publisher(for: \.canCheckForUpdates).eraseToAnyPublisher()
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    func start() throws {
        try controller.updater.start()
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}

@Loggable
@MainActor
final class SparkleUpdater: ObservableObject {
    enum State: Equatable {
        case notStarted
        case ready
        case unavailable
        case disabledForDevelopment
    }

    static let shared = SparkleUpdater(
        service: StandardSparkleUpdateService(),
        isUpdaterEnabled: {
            #if DEBUG
                false
            #else
                true
            #endif
        }()
    )

    @Published private(set) var state: State = .notStarted
    @Published private var serviceCanCheckForUpdates = false

    private let service: SparkleUpdateService
    private let isUpdaterEnabled: Bool

    var canCheckForUpdates: Bool {
        state == .ready && serviceCanCheckForUpdates
    }

    var canRetryStart: Bool {
        state == .unavailable
    }

    var automaticallyChecksForUpdates: Bool {
        get {
            service.automaticallyChecksForUpdates
        }
        set {
            objectWillChange.send()
            service.automaticallyChecksForUpdates = newValue
        }
    }

    init(service: SparkleUpdateService, isUpdaterEnabled: Bool) {
        self.service = service
        self.isUpdaterEnabled = isUpdaterEnabled
        self.serviceCanCheckForUpdates = service.canCheckForUpdates

        service.canCheckForUpdatesPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$serviceCanCheckForUpdates)
    }

    func start() {
        guard isUpdaterEnabled else {
            state = .disabledForDevelopment
            return
        }

        do {
            try service.start()
            serviceCanCheckForUpdates = service.canCheckForUpdates
            state = .ready
        } catch {
            serviceCanCheckForUpdates = false
            state = .unavailable
            log.error(
                "Sparkle updater failed to start: \(ApplicationLogPrivacy.errorDescription(error))"
            )
        }
    }

    func retryStart() {
        guard canRetryStart else { return }
        start()
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }

        ApplicationPresentationController.shared.prepareToPresentWindow()
        ApplicationPresentationController.shared.activate()
        service.checkForUpdates()
    }
}
