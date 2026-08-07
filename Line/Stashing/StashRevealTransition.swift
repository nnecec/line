//
//  StashRevealTransition.swift
//  Line
//
//  Pure state for the single-window reveal invariant and async transition tokens.
//

import CoreGraphics
import Foundation

struct StashRevealTransition {
    enum StablePhase: Equatable {
        case hidden
        case revealed
    }

    struct Token: Equatable {
        let windowID: CGWindowID
        fileprivate let id: UUID
    }

    struct RevealRequest: Equatable {
        let token: Token
        let previousRevealedWindowID: CGWindowID?
    }

    private enum Phase: Equatable {
        case stable(StablePhase)
        case transitioning(target: StablePhase, fallback: StablePhase, token: Token)
    }

    private let throttleInterval: TimeInterval
    private var phases: [CGWindowID: Phase] = [:]
    private var lastTransitionTime: [CGWindowID: TimeInterval] = [:]
    private var revealedWindowID: CGWindowID?

    init(throttleInterval: TimeInterval = 0.1) {
        self.throttleInterval = throttleInterval
    }

    func isWindowRevealed(_ windowID: CGWindowID) -> Bool {
        revealedWindowID == windowID
    }

    func revealedWindowID(excluding windowID: CGWindowID) -> CGWindowID? {
        revealedWindowID == windowID ? nil : revealedWindowID
    }

    mutating func beginReveal(windowID: CGWindowID, now: TimeInterval) -> RevealRequest? {
        if let revealedWindowID, isRevealInFlight(revealedWindowID) {
            return nil
        }
        guard !isWindowRevealed(windowID), !isRevealInFlight(windowID) else {
            return nil
        }
        guard !isThrottled(windowID: windowID, now: now) else {
            return nil
        }

        let token = Token(windowID: windowID, id: UUID())
        let previousRevealedWindowID = revealedWindowID
        for otherWindowID in Array(phases.keys)
            where otherWindowID != windowID && otherWindowID != revealedWindowID {
            if case .transitioning(target: .revealed, fallback: _, token: _) = phases[otherWindowID] {
                phases[otherWindowID] = .stable(.hidden)
            }
        }

        phases[windowID] = .transitioning(
            target: .revealed,
            fallback: .hidden,
            token: token
        )
        return RevealRequest(token: token, previousRevealedWindowID: previousRevealedWindowID)
    }

    /// Claims the single revealed slot immediately before the physical reveal starts.
    mutating func activate(_ token: Token) -> Bool {
        guard case let .transitioning(target: .revealed, fallback: _, token: currentToken) = phases[token.windowID],
              currentToken == token
        else {
            return false
        }

        revealedWindowID = token.windowID
        return true
    }

    mutating func beginHide(
        windowID: CGWindowID,
        now: TimeInterval,
        allowUnrevealed: Bool,
        shouldThrottle: Bool
    ) -> Token? {
        guard allowUnrevealed || isWindowRevealed(windowID) else {
            return nil
        }
        guard !shouldThrottle || !isThrottled(windowID: windowID, now: now) else {
            return nil
        }

        let token = Token(windowID: windowID, id: UUID())
        let fallback: StablePhase = isWindowRevealed(windowID) ? .revealed : .hidden
        phases[windowID] = .transitioning(
            target: .hidden,
            fallback: fallback,
            token: token
        )
        return token
    }

    mutating func complete(_ token: Token) -> Bool {
        guard case let .transitioning(target, _, currentToken) = phases[token.windowID],
              currentToken == token
        else {
            return false
        }

        phases[token.windowID] = .stable(target)
        switch target {
        case .hidden:
            if revealedWindowID == token.windowID {
                revealedWindowID = nil
            }
        case .revealed:
            for otherWindowID in Array(phases.keys) where otherWindowID != token.windowID {
                phases[otherWindowID] = .stable(.hidden)
            }
            revealedWindowID = token.windowID
        }
        return true
    }

    mutating func fail(_ token: Token) -> Bool {
        guard case let .transitioning(_, fallback, currentToken) = phases[token.windowID],
              currentToken == token
        else {
            return false
        }

        phases[token.windowID] = .stable(fallback)
        if fallback == .revealed {
            revealedWindowID = token.windowID
        } else if revealedWindowID == token.windowID {
            revealedWindowID = nil
        }
        return true
    }

    /// Marks a window revealed after an external resize put it fully on screen.
    mutating func markRevealed(windowID: CGWindowID) {
        for otherWindowID in Array(phases.keys) where otherWindowID != windowID {
            phases[otherWindowID] = .stable(.hidden)
        }
        phases[windowID] = .stable(.revealed)
        revealedWindowID = windowID
    }

    mutating func remove(windowID: CGWindowID) {
        phases.removeValue(forKey: windowID)
        lastTransitionTime.removeValue(forKey: windowID)
        if revealedWindowID == windowID {
            revealedWindowID = nil
        }
    }

    private mutating func isThrottled(windowID: CGWindowID, now: TimeInterval) -> Bool {
        if let last = lastTransitionTime[windowID], now - last < throttleInterval {
            return true
        }
        lastTransitionTime[windowID] = now
        return false
    }

    private func isRevealInFlight(_ windowID: CGWindowID) -> Bool {
        guard case .transitioning(target: .revealed, fallback: _, token: _) = phases[windowID] else {
            return false
        }
        return true
    }
}
