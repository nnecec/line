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
    }

    static func prepare(
        action: BoundWindowAction,
        parentAction: BoundWindowAction? = nil,
        window: Window?,
        screen: NSScreen? = nil,
        bounds: CGRect? = nil,
        padding: PaddingConfiguration? = nil,
        initialMousePosition: CGPoint = .zero,
        settings: SettingsSnapshot? = nil
    ) async -> PreparedResize {
        let resolvedScreen = screen
            ?? window.flatMap { ScreenUtility.screenContaining($0) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        let resolvedBounds = bounds ?? resolvedScreen.cgSafeScreenFrame
        let resolvedPadding = padding ?? settings?.padding ?? SettingsSnapshot.live(for: resolvedScreen).padding
        let resolvedState = await resolveState(for: window)

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
    /// Prefer this for high-frequency paths such as grid hover previews.
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

    private static func resolveState(for window: Window?) async -> ResolvedState {
        guard let window else {
            return .empty
        }

        let resolvedWindowProperties = Window.ResolvedProperties(from: window)
        let resolvedRecord = await WindowRecords.ResolvedRecord(for: window)
        let windowProperties = WindowProperties(
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
