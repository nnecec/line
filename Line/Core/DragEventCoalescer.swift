//
//  DragEventCoalescer.swift
//  Line
//
//  Lock-protected latest-state scheduler for passive drag events.
//

import Foundation

final class DragEventCoalescer<State: Sendable>: @unchecked Sendable {
    enum Event: Sendable {
        case dragged(State)
        case released(State)
    }

    struct ScheduledEvent: Sendable {
        let generation: UInt
        let event: Event
    }

    private let lock = NSLock()
    private var pendingDragged: State?
    private var pendingReleased: State?
    private var isDrainScheduled = false
    private var currentGeneration: UInt = 0
    private var currentDrainToken: UInt = 0
    private var isTerminated = false

    /// Queues the newest position. Returns true only when the caller must start a drain.
    @discardableResult
    func submitDragged(_ state: State) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isTerminated else { return false }
        pendingDragged = state
        guard !isDrainScheduled else { return false }
        isDrainScheduled = true
        currentDrainToken &+= 1
        return true
    }

    /// Queues termination and discards every pending position. Release always wins.
    @discardableResult
    func submitReleased(_ state: State) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        currentGeneration &+= 1
        isTerminated = true
        pendingDragged = nil
        pendingReleased = state
        guard !isDrainScheduled else { return false }
        isDrainScheduled = true
        currentDrainToken &+= 1
        return true
    }

    /// Takes one event. A caller that receives an event should continue draining until nil.
    func next() -> ScheduledEvent? {
        lock.lock()
        defer { lock.unlock() }

        if let state = pendingReleased {
            pendingReleased = nil
            return ScheduledEvent(generation: currentGeneration, event: .released(state))
        }
        if let state = pendingDragged {
            pendingDragged = nil
            return ScheduledEvent(generation: currentGeneration, event: .dragged(state))
        }

        isDrainScheduled = false
        return nil
    }

    func isCurrent(_ generation: UInt) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return currentGeneration == generation
    }

    func drainToken() -> UInt {
        lock.lock()
        defer { lock.unlock() }
        return currentDrainToken
    }

    func isCurrentDrain(_ token: UInt) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return currentDrainToken == token
    }

    /// Invalidates queued work and advances the session generation.
    func invalidate() {
        lock.lock()
        pendingDragged = nil
        pendingReleased = nil
        isDrainScheduled = false
        currentGeneration &+= 1
        currentDrainToken &+= 1
        isTerminated = false
        lock.unlock()
    }

    var generation: UInt {
        lock.lock()
        defer { lock.unlock() }
        return currentGeneration
    }
}
