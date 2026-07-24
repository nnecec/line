//
//  WindowResizeExecution.swift
//  Line
//
//  Created by Codex on 2026-07-09.
//

import AppKit
import Foundation
import SwiftUI

@MainActor
enum WindowResizeExecution {
    struct SettingsSnapshot {
        var padding: PaddingConfiguration

        static func live(for screen: NSScreen) -> SettingsSnapshot {
            SettingsSnapshot(padding: PaddingConfiguration.getConfiguredPadding(for: screen))
        }
    }

    struct ResolvedState {
        var windowProperties: WindowProperties?
        var record: WindowRecord?
        var resolvedWindowProperties: Window.ResolvedProperties?
        var resolvedRecord: WindowRecords.ResolvedRecord?

        static let empty = ResolvedState(
            windowProperties: nil,
            record: nil,
            resolvedWindowProperties: nil,
            resolvedRecord: nil
        )
    }

    struct PreparedResize {
        let action: BoundWindowAction
        let parentAction: BoundWindowAction?
        let initialMousePosition: CGPoint
        let request: WindowResizeRequest
        let targetFrame: ComputedFrame
        let sidesToAdjust: Edge.Set?
        let resolvedWindowProperties: Window.ResolvedProperties?
        let resolvedRecord: WindowRecords.ResolvedRecord?

        var window: Window? { request.window }
        var screen: NSScreen { request.screen }
        var bounds: CGRect { request.bounds }
        var padding: PaddingConfiguration { request.padding }
        var paddedBounds: CGRect { request.paddedBounds }
        var windowProperties: WindowProperties? { request.windowProperties }
        var record: WindowRecord? { request.record }
    }

    /// Session-scoped layout frame: prefer a stash revealed frame when present.
    nonisolated static func layoutFrame(revealedFrame: CGRect?, currentFrame: CGRect) -> CGRect {
        revealedFrame ?? currentFrame
    }

    /// Open a Window Action Session or grid interaction: resolve window state once and
    /// capture a session-scoped layout frame (including stash revealed frame when present).
    static func bootstrap(
        window: Window?,
        screen: NSScreen? = nil,
        initialMousePosition: CGPoint = .zero,
        action: BoundWindowAction = BoundWindowAction(action: .special(.noSelection), keybind: []),
        parentAction: BoundWindowAction? = nil,
        revealedFrameForStashedWindow: ((CGWindowID) async -> CGRect?)? = nil
    ) async -> PreparedResize {
        var windowProperties: WindowProperties?
        if let window {
            let revealedFrame: CGRect?
            if let revealedFrameForStashedWindow {
                revealedFrame = await revealedFrameForStashedWindow(window.cgWindowID)
            } else {
                revealedFrame = await StashManager.shared.getRevealedFrameForStashedWindow(
                    id: window.cgWindowID
                )
            }
            let frame = layoutFrame(revealedFrame: revealedFrame, currentFrame: window.frame)
            windowProperties = WindowProperties(frame: frame, isResizable: window.isResizable)
        }

        return await prepare(
            action: action,
            parentAction: parentAction,
            window: window,
            screen: screen,
            initialMousePosition: initialMousePosition,
            windowProperties: windowProperties
        )
    }

    /// Mid-session action or screen change: reuse bootstrap layout snapshot (no AX re-read).
    static func transition(
        from current: PreparedResize,
        toAction: BoundWindowAction,
        parentAction: BoundWindowAction? = nil,
        window: Window? = nil,
        screen: NSScreen? = nil,
        bounds: CGRect? = nil,
        padding: PaddingConfiguration? = nil
    ) -> PreparedResize {
        let resolvedScreen = screen ?? current.screen
        let resolvedBounds: CGRect
        if let bounds {
            resolvedBounds = bounds
        } else if screen != nil {
            resolvedBounds = resolvedScreen.cgSafeScreenFrame
        } else {
            resolvedBounds = current.bounds
        }

        let resolvedPadding: PaddingConfiguration
        if let padding {
            resolvedPadding = padding
        } else if screen != nil {
            resolvedPadding = SettingsSnapshot.live(for: resolvedScreen).padding
        } else {
            resolvedPadding = current.padding
        }

        return prepareResolved(
            action: toAction,
            parentAction: parentAction,
            window: window ?? current.window,
            screen: resolvedScreen,
            bounds: resolvedBounds,
            padding: resolvedPadding,
            initialMousePosition: current.initialMousePosition,
            windowProperties: current.windowProperties,
            record: current.record,
            resolvedWindowProperties: current.resolvedWindowProperties,
            resolvedRecord: current.resolvedRecord
        )
    }

    /// Immediate apply: re-resolve live window state while inheriting the session layout override.
    static func prepareImmediate(
        from session: PreparedResize,
        action: BoundWindowAction? = nil,
        parentAction: BoundWindowAction? = nil,
        window: Window? = nil,
        screen: NSScreen? = nil,
        bounds: CGRect? = nil,
        padding: PaddingConfiguration? = nil
    ) async -> PreparedResize {
        await prepare(
            action: action ?? session.action,
            parentAction: parentAction ?? session.parentAction,
            window: window ?? session.window,
            screen: screen ?? session.screen,
            bounds: bounds ?? session.bounds,
            padding: padding ?? session.padding,
            initialMousePosition: session.initialMousePosition,
            windowProperties: session.windowProperties
        )
    }

    static func prepare(
        action: BoundWindowAction,
        parentAction: BoundWindowAction? = nil,
        window: Window?,
        screen: NSScreen? = nil,
        bounds: CGRect? = nil,
        padding: PaddingConfiguration? = nil,
        initialMousePosition: CGPoint = .zero,
        settings: SettingsSnapshot? = nil,
        windowProperties: WindowProperties? = nil
    ) async -> PreparedResize {
        let resolvedScreen = screen
            ?? window.flatMap { ScreenUtility.screenContaining($0) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        let resolvedBounds = bounds ?? resolvedScreen.cgSafeScreenFrame
        let resolvedPadding = padding ?? settings?.padding ?? SettingsSnapshot.live(for: resolvedScreen).padding
        let resolvedState = await resolveState(for: window, windowPropertiesOverride: windowProperties)

        return prepareResolved(
            action: action,
            parentAction: parentAction,
            screen: resolvedScreen,
            bounds: resolvedBounds,
            padding: resolvedPadding,
            initialMousePosition: initialMousePosition,
            window: window,
            resolvedState: resolvedState
        )
    }

    /// Prepare a resize using already-resolved window properties (no AX / async work).
    /// Prefer this for high-frequency paths such as grid hover previews and session transitions.
    static func prepareResolved(
        action: BoundWindowAction,
        parentAction: BoundWindowAction? = nil,
        window: Window? = nil,
        screen: NSScreen,
        bounds: CGRect,
        padding: PaddingConfiguration,
        initialMousePosition: CGPoint = .zero,
        windowProperties: WindowProperties?,
        record: WindowRecord?,
        resolvedWindowProperties: Window.ResolvedProperties? = nil,
        resolvedRecord: WindowRecords.ResolvedRecord? = nil
    ) -> PreparedResize {
        prepareResolved(
            action: action,
            parentAction: parentAction,
            screen: screen,
            bounds: bounds,
            padding: padding,
            initialMousePosition: initialMousePosition,
            window: window,
            resolvedState: ResolvedState(
                windowProperties: windowProperties,
                record: record,
                resolvedWindowProperties: resolvedWindowProperties,
                resolvedRecord: resolvedRecord
            )
        )
    }

    private static func prepareResolved(
        action: BoundWindowAction,
        parentAction: BoundWindowAction?,
        screen: NSScreen,
        bounds: CGRect,
        padding: PaddingConfiguration,
        initialMousePosition: CGPoint,
        window: Window?,
        resolvedState: ResolvedState
    ) -> PreparedResize {
        let request = WindowResizeRequest(
            window: window,
            action: action.action,
            screen: screen,
            bounds: bounds,
            padding: padding,
            windowProperties: resolvedState.windowProperties,
            record: resolvedState.record
        )
        let result = WindowFrameResolver.calculateFrame(for: request)

        return PreparedResize(
            action: action,
            parentAction: parentAction,
            initialMousePosition: initialMousePosition,
            request: request,
            targetFrame: ComputedFrame(raw: result.frame, padded: result.frame),
            sidesToAdjust: result.sidesToAdjust,
            resolvedWindowProperties: resolvedState.resolvedWindowProperties,
            resolvedRecord: resolvedState.resolvedRecord
        )
    }

    private static func resolveState(
        for window: Window?,
        windowPropertiesOverride: WindowProperties? = nil
    ) async -> ResolvedState {
        guard let window else {
            if let windowPropertiesOverride {
                return ResolvedState(
                    windowProperties: windowPropertiesOverride,
                    record: nil,
                    resolvedWindowProperties: nil,
                    resolvedRecord: nil
                )
            }
            return .empty
        }

        let resolvedWindowProperties = Window.ResolvedProperties(from: window)
        let resolvedRecord = await WindowRecords.ResolvedRecord(for: window)
        // When an override is provided (e.g. stash revealed frame), preserve its
        // frame for layout math instead of re-reading the live AX frame.
        let windowProperties = windowPropertiesOverride ?? WindowProperties(
            frame: resolvedWindowProperties.frame,
            isResizable: resolvedWindowProperties.isResizable
        )
        let record = WindowRecord(
            initialFrame: resolvedRecord.initialFrame,
            lastAction: resolvedRecord.lastAction?.action
        )

        return ResolvedState(
            windowProperties: windowProperties,
            record: record,
            resolvedWindowProperties: resolvedWindowProperties,
            resolvedRecord: resolvedRecord
        )
    }
}
