//
//  StashedWindowStore.swift
//  Line
//
//  Created by Guillaume Clédat on 28/05/2025.
//

import Defaults
import Foundation
import Scribe
import SwiftUI

protocol StashedWindowsStoreDelegate: AnyObject {
    var stashedWindowVisiblePadding: CGFloat { get }
    func onStashedWindowsRestored()
}

/// Keep the stashed windows and the revealed window ids both in memory and in Defaults.
/// Restore windows stashed from a previous session.
@Loggable
final class StashedWindowsStore {
    weak var delegate: StashedWindowsStoreDelegate?

    private(set) var stashed: [CGWindowID: StashedWindowInfo] = [:]
    private(set) var revealed: Set<CGWindowID> = []

    /// Hold data from `Defaults[.stashManagerStashedWindows]` for windows that failed to be restored.
    private var failedToRestore: [CGWindowID: WindowAction] = [:]
    private var spaceObserverTask: Task<(), Never>?

    // MARK: - Public methods

    func restore() async {
        await restoreStashedWindows()
    }

    func isWindowRevealed(_ id: CGWindowID) -> Bool {
        revealed.contains(id)
    }

    func markWindowAsRevealed(_ id: CGWindowID) {
        revealed.insert(id)
    }

    func markWindowAsHidden(_ id: CGWindowID) {
        revealed.remove(id)
    }

    /// Return the stashed window that match the given `action` and `screen`
    func stashedWindow(for boundAction: BoundWindowAction, on screen: NSScreen) -> StashedWindowInfo? {
        if let match = stashed.values.first(where: { stashedWindow in
            Self.stashActionsMatch(requested: boundAction, stashed: stashedWindow.action) &&
                stashedWindow.screen.isSameScreen(screen)
        }) {
            return match
        }

        // Fallback for actions that predate the stash identity payload.
        guard boundAction.stashEdge == nil else {
            return nil
        }

        return stashed.values.first { $0.screen.isSameScreen(screen) }
    }

    func setStashedWindow(cgWindowID: CGWindowID, to window: StashedWindowInfo?) {
        guard stashed[cgWindowID] != window else {
            return
        }

        stashed[cgWindowID] = window

        Defaults[.stashManagerStashedWindows] = stashed.compactMapValues(\.action.action.stashPersistenceValue)
        log.info("Stashed windows updated (count: \(stashed.count))")
    }

    static func stashActionsMatch(requested: BoundWindowAction, stashed: BoundWindowAction) -> Bool {
        guard let requestedEdge = requested.stashEdge,
              let stashedEdge = stashed.stashEdge
        else {
            return false
        }

        return requestedEdge == stashedEdge && requested.name == stashed.name
    }

    // MARK: Private methods

    private func restoreStashedWindows() async {
        let windows = WindowUtility.windowList()
        let defaultStashedWindows = Defaults[.stashManagerStashedWindows]
        var restoredStashedWindows: [CGWindowID: StashedWindowInfo] = [:]

        for (windowId, persistedAction) in defaultStashedWindows {
            guard let action = WindowAction(stashPersistenceValue: persistedAction) else {
                log.error("Failed to decode persisted stash action for window \(windowId).")
                continue
            }

            guard let stashedWindow = await getStashedWindow(for: windowId, in: windows, action: action) else {
                failedToRestore[windowId] = action
                continue
            }

            restoredStashedWindows[windowId] = stashedWindow
        }

        if !restoredStashedWindows.isEmpty {
            stashed = restoredStashedWindows
            log.info("\(restoredStashedWindows.count) stashed window restored.")
            delegate?.onStashedWindowsRestored()
        }

        if !failedToRestore.isEmpty {
            log.error("Failed to restore \(failedToRestore.count) window(s).")

            // Window restoration usually fail because the window is on another space and will
            // not be returned by WindowEngine.windowList until the user goes to that space.
            spaceObserverTask = Task { [weak self] in
                let notifications = NSWorkspace.shared.notificationCenter.notifications(
                    named: NSWorkspace.activeSpaceDidChangeNotification
                )

                for await _ in notifications {
                    guard !Task.isCancelled else { return }
                    await self?.onSpaceChanged()
                }
            }
        }
    }

    private func onSpaceChanged() async {
        let windows = WindowUtility.windowList()
        var restored = 0

        log.info("Space changed. Attempting to restore windows.")

        for (windowId, direction) in failedToRestore {
            guard let stashedWindow = await getStashedWindow(for: windowId, in: windows, action: direction) else {
                continue
            }

            stashed[windowId] = stashedWindow
            failedToRestore.removeValue(forKey: windowId)
            restored += 1
        }

        if restored > 0 {
            delegate?.onStashedWindowsRestored()
        }

        if failedToRestore.isEmpty {
            spaceObserverTask?.cancel()
            spaceObserverTask = nil
        }
    }

    private func getStashedWindow(for windowId: CGWindowID, in windows: [Window], action: WindowAction) async -> StashedWindowInfo? {
        guard let window = windows.first(where: { $0.cgWindowID == windowId }) else { return nil }
        guard let screen = ScreenUtility.screenContaining(window) ?? NSScreen.main else { return nil }
        guard let peekSize = delegate?.stashedWindowVisiblePadding else { return nil }

        // TODO: Properly recreate BoundWindowAction from persisted data
        // For now, wrap the action in a BoundWindowAction with empty keybind
        let boundAction = BoundWindowAction(action: action, keybind: [])

        return await StashedWindowInfo.create(
            window: window,
            screen: screen,
            action: boundAction,
            peekSize: peekSize
        )
    }
}

extension WindowAction {
    var stashPersistenceValue: String? {
        guard stashEdge != nil else {
            return nil
        }

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    init?(stashPersistenceValue value: String) {
        if let data = value.data(using: .utf8),
           let action = try? JSONDecoder().decode(WindowAction.self, from: data) {
            guard action.stashEdge != nil else {
                return nil
            }

            self = action
            return
        }

        let legacyEdge = StashEdge(rawValue: value.lowercased()) ?? .left
        self = .stash(name: value, edge: legacyEdge)
    }
}
