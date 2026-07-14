//
//  SpecialActionCalculator.swift
//  Line
//
//  Created via architecture refactor on 2026-07-02.
//
//  完整实现 SpecialAction 的帧计算逻辑。
//  处理 undo/initialFrame 等需要访问 WindowRecords 的动作。
//

import AppKit
import CoreGraphics
import Foundation

extension WindowAction.SpecialAction {
    @MainActor
    func calculateFrameWithRequest(for request: WindowResizeRequest) -> FrameCalculationResult {
        switch self {
        case .undo:
            calculateUndoFrame(for: request)

        case .initialFrame:
            calculateInitialFrame(for: request)

        case .noAction, .noSelection, .hide, .minimize, .minimizeOthers:
            // 这些动作不计算帧
            FrameCalculationResult(frame: .zero)
        }
    }

    // MARK: - Undo Frame Calculation

    @MainActor
    private func calculateUndoFrame(for request: WindowResizeRequest) -> FrameCalculationResult {
        // 如果有记录的上一个动作,递归计算它的帧
        if let lastAction = request.record?.lastAction {
            let recursiveRequest = request.withAction(lastAction)
            return WindowFrameResolver.calculateFrame(for: recursiveRequest)
        } else if let properties = request.windowProperties {
            // 没有上一个动作,返回当前帧
            return FrameCalculationResult(frame: properties.frame)
        }

        return FrameCalculationResult(frame: .zero)
    }

    // MARK: - Initial Frame Calculation

    @MainActor
    private func calculateInitialFrame(for request: WindowResizeRequest) -> FrameCalculationResult {
        // 如果有记录的初始帧,使用它
        if let initialFrame = request.record?.initialFrame {
            return FrameCalculationResult(frame: initialFrame)
        } else if let properties = request.windowProperties {
            // 没有记录,返回当前帧
            return FrameCalculationResult(frame: properties.frame)
        }

        return FrameCalculationResult(frame: .zero)
    }
}

// MARK: - WindowRecords Integration (异步)

extension WindowRecords {
    /// 异步获取窗口记录的快照。
    /// 这是 actor-isolated 的安全访问方法。
    func getRecordSnapshot(for window: Window) async -> WindowRecord? {
        // 获取初始帧和最后动作
        let initialFrame = getInitialFrame(for: window)
        let lastActionOld = getLastAction(for: window)

        // 转换 lastAction: 提取内部的 WindowAction
        let lastAction: WindowAction? = lastActionOld?.action

        return WindowRecord(
            initialFrame: initialFrame,
            lastAction: lastAction
        )
    }
}

// MARK: - WindowResizeRequest with Records (异步构造)

extension WindowResizeRequest {
    /// 异步创建包含 WindowRecords 数据的请求。
    /// 用于需要 undo/initialFrame 的场景。
    @MainActor
    static func withRecords(
        window: Window,
        action: WindowAction,
        screen: NSScreen,
        bounds: CGRect,
        padding: PaddingConfiguration
    ) async -> WindowResizeRequest {
        let windowProperties = WindowProperties(window: window)
        let record = await WindowRecords.shared.getRecordSnapshot(for: window)

        return WindowResizeRequest(
            window: window,
            action: action,
            screen: screen,
            bounds: bounds,
            padding: padding,
            windowProperties: windowProperties,
            record: record,
            visibleWindowFrames: nil
        )
    }
}
