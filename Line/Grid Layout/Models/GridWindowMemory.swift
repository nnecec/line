//
//  GridWindowMemory.swift
//  Line
//

import CoreGraphics
import Foundation

/// Session-stable identity for a concrete application window.
struct GridWindowIdentity: Hashable {
    let processIdentifier: pid_t
    let windowID: CGWindowID
}

/// Window identity scoped to the display where grid mode is opened.
struct GridWindowMemoryKey: Hashable {
    let processIdentifier: pid_t
    let windowID: CGWindowID
    let screenIdentifier: String

    init(
        processIdentifier: pid_t,
        windowID: CGWindowID,
        screenIdentifier: String
    ) {
        self.processIdentifier = processIdentifier
        self.windowID = windowID
        self.screenIdentifier = screenIdentifier
    }

    init(identity: GridWindowIdentity, screenIdentifier: String) {
        self.init(
            processIdentifier: identity.processIdentifier,
            windowID: identity.windowID,
            screenIdentifier: screenIdentifier
        )
    }
}

/// Bounded, process-local grid size memory for individual windows.
struct GridWindowMemoryStore {
    private let capacity: Int
    private var sizes: [GridWindowMemoryKey: GridSize] = [:]
    private var insertionOrder: [GridWindowMemoryKey] = []

    init(capacity: Int = 256) {
        self.capacity = max(1, capacity)
    }

    var count: Int { sizes.count }

    func size(for key: GridWindowMemoryKey) -> GridSize? {
        sizes[key]
    }

    mutating func save(_ size: GridSize, for key: GridWindowMemoryKey) {
        if sizes[key] != nil {
            sizes[key] = size
            return
        }

        if sizes.count >= capacity, let oldestKey = insertionOrder.first {
            sizes.removeValue(forKey: oldestKey)
            insertionOrder.removeFirst()
        }

        sizes[key] = size
        insertionOrder.append(key)
    }

    mutating func removeAll(processIdentifier: pid_t) {
        sizes = sizes.filter { $0.key.processIdentifier != processIdentifier }
        insertionOrder.removeAll { $0.processIdentifier == processIdentifier }
    }

    mutating func removeAll() {
        sizes.removeAll()
        insertionOrder.removeAll()
    }
}

/// Pure lifecycle decisions shared by grid application and coordinator cleanup.
enum GridMemoryLifecyclePolicy {
    static func shouldSaveAfterSuccessfulApply(
        requested: Bool,
        hasMemorySize: Bool,
        isAccessibilityGranted: Bool,
        isTargetApplicationRunning: Bool,
        isSessionGenerationCurrent: Bool
    ) -> Bool {
        requested
            && hasMemorySize
            && isAccessibilityGranted
            && isTargetApplicationRunning
            && isSessionGenerationCurrent
    }

    static func shouldCancelGrid(
        targetProcessIdentifier: pid_t?,
        terminatedProcessIdentifier: pid_t
    ) -> Bool {
        targetProcessIdentifier == terminatedProcessIdentifier
    }
}
