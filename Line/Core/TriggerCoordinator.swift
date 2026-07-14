//
//  TriggerCoordinator.swift
//  Line
//
//  Created by Claude on 2026-07-08.

import Defaults
import Scribe
import SwiftUI

/// Coordinates trigger mechanisms (keyboard shortcuts and middle-click) for opening/closing Line.
///
/// Provides a clean abstraction over KeybindTrigger and MiddleClickTrigger, allowing:
/// - Centralized trigger lifecycle management (setup/teardown)
/// - Dependency injection for testing (callbacks can be mocked)
/// - Clear separation between trigger detection and action execution
@Loggable
@MainActor
final class TriggerCoordinator {
    // MARK: - Dependencies

    private let windowActionCache: WindowActionCache

    // MARK: - Triggers

    private(set) lazy var keybindTrigger: KeybindTrigger = .init(
        windowActionCache: windowActionCache,
        openCallback: { [weak self] action in
            Task {
                await self?.onOpen?(action)
            }
        },
        closeCallback: { [weak self] forceClose in
            Task {
                await self?.onClose?(forceClose)
            }
        },
        checkIfLineOpen: { [weak self] in
            self?.checkIfLineOpen?() ?? false
        }
    )

    private(set) lazy var middleClickTrigger: MiddleClickTrigger = .init(
        openCallback: { [weak self] action in
            Task {
                await self?.onOpen?(action)
            }
        },
        closeCallback: { [weak self] forceClose in
            Task {
                await self?.onClose?(forceClose)
            }
        },
        checkIfLineOpen: { [weak self] in
            self?.checkIfLineOpen?() ?? false
        }
    )

    // MARK: - Callbacks (late binding)

    private var onOpen: ((BoundWindowAction) async -> ())?
    private var onClose: ((Bool) async -> ())?
    private var checkIfLineOpen: (() -> Bool)?

    // MARK: - Initialization

    init(windowActionCache: WindowActionCache) {
        self.windowActionCache = windowActionCache
    }

    // MARK: - Late Binding

    /// Bind callbacks after initialization to resolve circular dependencies.
    /// - Parameters:
    ///   - onOpen: Called when a trigger requests to open Line
    ///   - onClose: Called when a trigger requests to close Line
    ///   - checkIfLineOpen: Returns whether Line is currently active
    func bind(
        onOpen: @escaping (BoundWindowAction) async -> (),
        onClose: @escaping (Bool) async -> (),
        checkIfLineOpen: @escaping () -> Bool
    ) {
        self.onOpen = onOpen
        self.onClose = onClose
        self.checkIfLineOpen = checkIfLineOpen
    }

    // MARK: - Public Interface

    /// Start listening for trigger events (keyboard shortcuts and middle-click).
    func setup() async {
        log.info("Setting up triggers")
        await keybindTrigger.start()
        middleClickTrigger.start()
    }

    /// Stop listening for trigger events.
    func teardown() {
        log.info("Tearing down triggers")
        keybindTrigger.stop()
        middleClickTrigger.stop()
    }

    /// Suppress the next special event passthrough (e.g., emoji key).
    /// Called when mouse movement is detected during a session.
    func suppressNextSpecialEvent() {
        keybindTrigger.canPassthroughNextSpecialEvent = false
    }
}
