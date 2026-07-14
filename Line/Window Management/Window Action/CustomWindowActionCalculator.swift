//
//  CustomWindowActionCalculator.swift
//  Line
//
//  Created via architecture refactor on 2026-07-02.
//
//  完整实现 CustomWindowAction 的帧计算逻辑。
//  移植自 WindowFrameResolver.calculateCustomFrame。
//

import AppKit
import CoreGraphics
import Foundation

extension WindowAction.CustomWindowAction {
    func calculateFrame(for request: WindowResizeRequest) -> CGRect {
        let bounds = request.paddedBounds

        // 获取窗口大小
        let windowSize = calculateWindowSize(for: request, bounds: bounds)

        // 获取窗口位置
        let position = calculateWindowPosition(
            windowSize: windowSize,
            bounds: bounds,
            windowProperties: request.windowProperties
        )

        return CGRect(origin: position, size: windowSize)
    }

    // MARK: - Size Calculation

    private func calculateWindowSize(for request: WindowResizeRequest, bounds: CGRect) -> CGSize {
        let width: CGFloat
        let height: CGFloat

        switch sizeMode {
        case .custom:
            // 使用指定的宽度和高度
            width = calculateDimension(
                value: self.width,
                total: bounds.width,
                unit: unit
            )
            height = calculateDimension(
                value: self.height,
                total: bounds.height,
                unit: unit
            )

        case .preserveSize:
            // 保持当前窗口大小
            let size = request.windowProperties?.frame.size ?? bounds.size
            width = size.width
            height = size.height

        case .initialSize:
            // 使用初始窗口大小
            let size = request.record?.initialFrame?.size
                ?? request.windowProperties?.frame.size
                ?? bounds.size
            width = size.width
            height = size.height
        }

        return CGSize(width: width, height: height)
    }

    private func calculateDimension(
        value: Double?,
        total: CGFloat,
        unit: CustomWindowActionUnit
    ) -> CGFloat {
        guard let value else { return total }

        switch unit {
        case .pixels:
            return CGFloat(value)
        case .percentage:
            return total * CGFloat(value / 100.0)
        }
    }

    // MARK: - Position Calculation

    private func calculateWindowPosition(
        windowSize: CGSize,
        bounds: CGRect,
        windowProperties _: WindowProperties?
    ) -> CGPoint {
        switch positionMode {
        case .generic:
            // 使用 anchor 定位
            calculateAnchoredPosition(
                windowSize: windowSize,
                bounds: bounds,
                anchor: anchor
            )

        case .coordinates:
            // 使用精确坐标
            calculateCoordinatePosition(
                bounds: bounds,
                xPoint: xPoint,
                yPoint: yPoint,
                unit: unit
            )
        }
    }

    private func calculateAnchoredPosition(
        windowSize: CGSize,
        bounds: CGRect,
        anchor: CustomWindowActionAnchor
    ) -> CGPoint {
        let x: CGFloat
        let y: CGFloat

        switch anchor {
        case .none:
            // 没有锚点,使用默认位置
            x = bounds.minX
            y = bounds.minY

        case .topLeft:
            x = bounds.minX
            y = bounds.minY

        case .top:
            x = bounds.midX - windowSize.width / 2
            y = bounds.minY

        case .topRight:
            x = bounds.maxX - windowSize.width
            y = bounds.minY

        case .left:
            x = bounds.minX
            y = bounds.midY - windowSize.height / 2

        case .center:
            x = bounds.midX - windowSize.width / 2
            y = bounds.midY - windowSize.height / 2

        case .macOSCenter:
            // macOS 风格的居中 (有 Y 偏移)
            x = bounds.midX - windowSize.width / 2
            let yOffset = bounds.height / 10
            y = bounds.midY - windowSize.height / 2 - yOffset

        case .right:
            x = bounds.maxX - windowSize.width
            y = bounds.midY - windowSize.height / 2

        case .bottomLeft:
            x = bounds.minX
            y = bounds.maxY - windowSize.height

        case .bottom:
            x = bounds.midX - windowSize.width / 2
            y = bounds.maxY - windowSize.height

        case .bottomRight:
            x = bounds.maxX - windowSize.width
            y = bounds.maxY - windowSize.height
        }

        return CGPoint(x: x, y: y)
    }

    private func calculateCoordinatePosition(
        bounds: CGRect,
        xPoint: Double?,
        yPoint: Double?,
        unit: CustomWindowActionUnit
    ) -> CGPoint {
        let x: CGFloat
        let y: CGFloat

        if let xPoint {
            x = bounds.minX + calculateDimension(
                value: xPoint,
                total: bounds.width,
                unit: unit
            )
        } else {
            x = bounds.minX
        }

        if let yPoint {
            y = bounds.minY + calculateDimension(
                value: yPoint,
                total: bounds.height,
                unit: unit
            )
        } else {
            y = bounds.minY
        }

        return CGPoint(x: x, y: y)
    }
}
