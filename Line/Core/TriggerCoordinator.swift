//
//  TriggerCoordinator.swift
//  Line
//
//  Created by Claude on 2026-07-08.

import Defaults
import os
import Scribe
import SwiftUI

final class KeybindTriggerEventBuffer: @unchecked Sendable {
    enum Event: Equatable {
        case open(BoundWindowAction)
        case close(forceClose: Bool)
    }

    private struct State {
        var events: [Event] = []
        var isDrainScheduled = false
        var generation: UInt = 0
    }

    struct DrainToken: Equatable, Sendable {
        fileprivate let generation: UInt
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    func enqueue(_ event: Event) -> DrainToken? {
        state.withLock { state in
            if Self.canCoalesce(event),
               let lastIndex = state.events.indices.last,
               Self.canCoalesce(state.events[lastIndex]) {
                state.events[lastIndex] = event
            } else {
                state.events.append(event)
            }
            guard !state.isDrainScheduled else { return nil }
            state.isDrainScheduled = true
            return DrainToken(generation: state.generation)
        }
    }

    func popNext(for token: DrainToken) -> Event? {
        state.withLock { state in
            guard state.isDrainScheduled, state.generation == token.generation else {
                return nil
            }
            guard !state.events.isEmpty else {
                state.isDrainScheduled = false
                return nil
            }
            return state.events.removeFirst()
        }
    }

    func invalidate() {
        state.withLock { state in
            state.events.removeAll()
            state.generation &+= 1
            state.isDrainScheduled = false
        }
    }

    private static func canCoalesce(_ event: Event) -> Bool {
        guard case let .open(action) = event else { return false }

        switch action.action {
        case .standard, .custom:
            return true
        case .special(.noAction), .special(.noSelection):
            return true
        case .cycle, .focus, .incremental, .screen, .stash, .special:
            return false
        }
    }
}

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
    private let keybindEventBuffer = KeybindTriggerEventBuffer()

    // MARK: - Triggers

    private(set) lazy var keybindTrigger: KeybindTrigger = .init(
        windowActionCache: windowActionCache,
        openCallback: { [weak self, keybindEventBuffer] action in
            guard let token = keybindEventBuffer.enqueue(.open(action)) else { return }
            Task { @MainActor [weak self] in
                await self?.drainKeybindEvents(token: token)
            }
        },
        closeCallback: { [weak self, keybindEventBuffer] forceClose in
            guard let token = keybindEventBuffer.enqueue(.close(forceClose: forceClose)) else { return }
            Task { @MainActor [weak self] in
                await self?.drainKeybindEvents(token: token)
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

    private func drainKeybindEvents(token: KeybindTriggerEventBuffer.DrainToken) async {
        while let event = keybindEventBuffer.popNext(for: token) {
            switch event {
            case let .open(action):
                await onOpen?(action)
            case let .close(forceClose):
                await onClose?(forceClose)
            }
        }
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
        keybindEventBuffer.invalidate()
    }

    /// Suppress the next special event passthrough (e.g., emoji key).
    /// Called when mouse movement is detected during a session.
    func suppressNextSpecialEvent() {
        keybindTrigger.canPassthroughNextSpecialEvent = false
    }
}
