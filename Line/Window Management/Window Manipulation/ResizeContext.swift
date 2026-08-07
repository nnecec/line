//
//  ResizeContext.swift
//  Line
//
//  Lightweight wrapper around WindowResizeRequest for backward compatibility.
//  This allows existing code to continue working while we migrate to the new API.
//

import Scribe
import SwiftUI

@Loggable
@MainActor
final class ResizeContext {
    private var request: WindowResizeRequest

    var window: Window? { request.window }
    var screen: NSScreen? { request.screen }
    var bounds: CGRect { request.bounds }
    var padding: PaddingConfiguration { request.padding }
    var paddedBounds: CGRect { request.paddedBounds }

    // Legacy compatibility
    var resolvedWindowProperties: Window.ResolvedProperties?
    var lastAppliedFrame: CGRect = .zero
    var resolvedRecord: WindowRecords.ResolvedRecord?

    // For compatibility with code that modifies action
    private var _action: BoundWindowAction
    var action: BoundWindowAction {
        get { _action }
        set {
            _action = newValue
            rebuildRequest(action: newValue.action)
            _cachedTargetFrame = nil
        }
    }

    var parentAction: BoundWindowAction?
    var sidesToAdjust: Edge.Set?
    var initialMousePosition: CGPoint = .zero

    // Cached result
    private var _cachedTargetFrame: ComputedFrame?
    var cachedTargetFrame: ComputedFrame {
        if let cached = _cachedTargetFrame {
            return cached
        }
        let result = getTargetFrame()
        let computed = ComputedFrame(raw: result.0, padded: result.0)
        _cachedTargetFrame = computed
        return computed
    }

    init(
        window: Window? = nil,
        screen: NSScreen? = nil,
        bounds: CGRect? = nil,
        padding: PaddingConfiguration? = nil,
        action: BoundWindowAction = BoundWindowAction(action: .special(.noSelection), keybind: []),
        initialMousePosition: CGPoint = .zero
    ) {
        let finalScreen = screen ?? (window.map { ScreenUtility.screenContaining($0) ?? NSScreen.main } ?? NSScreen.main) ?? NSScreen.screens[0]
        let finalBounds = bounds ?? finalScreen.cgSafeScreenFrame
        let finalPadding = padding ?? PaddingConfiguration.getConfiguredPadding(for: finalScreen)

        self._action = action
        self.request = WindowResizeRequest(
            window: window,
            action: action.action,
            screen: finalScreen,
            bounds: finalBounds,
            padding: finalPadding
        )
        self.initialMousePosition = initialMousePosition
    }

    private func rebuildRequest(
        action: WindowAction? = nil,
        screen: NSScreen? = nil,
        bounds: CGRect? = nil,
        padding: PaddingConfiguration? = nil,
        windowProperties: WindowProperties? = nil,
        record: WindowRecord? = nil,
        preserveSnapshots: Bool = true
    ) {
        request = WindowResizeRequest(
            window: window,
            action: action ?? _action.action,
            screen: screen ?? self.screen ?? NSScreen.main ?? NSScreen.screens[0],
            bounds: bounds ?? self.bounds,
            padding: padding ?? self.padding,
            windowProperties: windowProperties ?? (preserveSnapshots ? request.windowProperties : nil),
            record: record ?? (preserveSnapshots ? request.record : nil)
        )
    }

    private static func makeRequestWindowProperties(from resolvedProperties: Window.ResolvedProperties) -> WindowProperties {
        WindowProperties(
            frame: resolvedProperties.frame,
            isResizable: resolvedProperties.isResizable
        )
    }

    private static func makeRequestRecord(from resolvedRecord: WindowRecords.ResolvedRecord) -> WindowRecord? {
        guard resolvedRecord.initialFrame != nil || resolvedRecord.lastAction != nil else {
            return nil
        }

        return WindowRecord(
            initialFrame: resolvedRecord.initialFrame,
            lastAction: resolvedRecord.lastAction?.action
        )
    }

    /// Compute frame using new API
    func getTargetFrame() -> (CGRect, Edge.Set?) {
        let result = WindowFrameResolver.calculateFrame(for: request)
        sidesToAdjust = result.sidesToAdjust
        return (result.frame, result.sidesToAdjust)
    }

    func refreshResolvedState() async {
        guard let window else { return }

        let windowProperties = Window.ResolvedProperties(from: window)
        let record = await WindowRecords.ResolvedRecord(for: window)
        let requestWindowProperties = Self.makeRequestWindowProperties(from: windowProperties)
        let requestRecord = Self.makeRequestRecord(from: record)

        resolvedWindowProperties = windowProperties
        resolvedRecord = record
        rebuildRequest(
            windowProperties: requestWindowProperties,
            record: requestRecord,
            preserveSnapshots: false
        )
        _cachedTargetFrame = nil
    }

    // MARK: - Legacy Compatibility Methods

    /// Legacy method for updating screen
    func setScreen(to screen: NSScreen) {
        rebuildRequest(
            screen: screen,
            bounds: screen.cgSafeScreenFrame,
            padding: PaddingConfiguration.getConfiguredPadding(for: screen)
        )
        // Clear cached frame
        _cachedTargetFrame = nil
    }

    /// Legacy method for updating action
    func setAction(to action: BoundWindowAction, parent: BoundWindowAction?) {
        _action = action
        parentAction = parent
        rebuildRequest(action: action.action)
        // Clear cached frame
        _cachedTargetFrame = nil
    }
}

// MARK: - ComputedFrame

struct ComputedFrame {
    let raw: CGRect
    let padded: CGRect

    static var zero: ComputedFrame {
        ComputedFrame(raw: .zero, padded: .zero)
    }
}

// MARK: - PreparedResize bridge (settings / drag still use ResizeContext)

extension WindowResizeExecution.PreparedResize {
    /// Build a Prepared Resize snapshot from a mutable ResizeContext (legacy / drag / settings).
    @MainActor
    init(context: ResizeContext) {
        let (frame, sides) = context.getTargetFrame()
        self.init(
            action: context.action,
            parentAction: context.parentAction,
            initialMousePosition: context.initialMousePosition,
            request: WindowResizeRequest(
                window: context.window,
                action: context.action.action,
                screen: context.screen ?? NSScreen.main ?? NSScreen.screens[0],
                bounds: context.bounds,
                padding: context.padding,
                windowProperties: context.resolvedWindowProperties.map {
                    WindowProperties(frame: $0.frame, isResizable: $0.isResizable)
                },
                record: context.resolvedRecord.map {
                    WindowRecord(initialFrame: $0.initialFrame, lastAction: $0.lastAction?.action)
                }
            ),
            targetFrame: ComputedFrame(raw: frame, padded: frame),
            sidesToAdjust: sides ?? context.sidesToAdjust,
            resolvedWindowProperties: context.resolvedWindowProperties,
            resolvedRecord: context.resolvedRecord
        )
    }
}
