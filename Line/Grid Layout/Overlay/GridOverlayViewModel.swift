//
//  GridOverlayViewModel.swift
//  Line
//
//  Manages grid overlay interaction state.
//  Created by nnecec on 2024-12-30.

//

import Foundation
import SwiftUI

/// Manages the state of the grid overlay: hover, click, and drag interactions.
@MainActor
final class GridOverlayViewModel: ObservableObject {
    // MARK: - Published State

    /// Current cell under the mouse (nil if outside grid).
    @Published private(set) var hoveredCell: GridCell?

    /// The region to highlight (from hover memory size or drag selection).
    @Published private(set) var selectedRegion: GridRegion?

    /// Current interaction mode.
    @Published private(set) var interactionMode: InteractionMode = .hovering

    // MARK: - Interaction Mode

    enum InteractionMode {
        case hovering
        case pressing(startCell: GridCell)
        case dragging(startCell: GridCell, currentCell: GridCell)
    }

    // MARK: - Dependencies

    private let geometry: GridGeometry
    private let rememberedSize: GridSize
    private let dragThreshold: CGFloat = 10.0

    // MARK: - Private State

    private var mouseDownPoint: CGPoint?
    private var mouseDownCell: GridCell?

    // MARK: - Initialization

    init(geometry: GridGeometry, rememberedSize: GridSize) {
        self.geometry = geometry
        self.rememberedSize = rememberedSize
    }

    // MARK: - Mouse Event Handlers

    /// Handle mouse moved (hover state).
    func handleMouseMoved(at globalPoint: CGPoint) {
        guard case .hovering = interactionMode else { return }

        hoveredCell = geometry.cell(atGlobalPoint: globalPoint)

        if let cell = hoveredCell {
            selectedRegion = geometry.region(startingAt: cell, size: rememberedSize)
        } else {
            selectedRegion = nil
        }
    }

    /// Handle mouse down (start click or drag).
    func handleMouseDown(at globalPoint: CGPoint) {
        guard case .hovering = interactionMode else { return }

        mouseDownPoint = globalPoint
        mouseDownCell = geometry.cell(atGlobalPoint: globalPoint)

        guard let startCell = mouseDownCell else {
            // Click outside grid - will be handled as cancel on mouse up
            return
        }

        // Immediately show 1x1 at the pressed cell
        interactionMode = .pressing(startCell: startCell)
        selectedRegion = .single(startCell)
    }

    /// Handle mouse dragged.
    func handleMouseDragged(at globalPoint: CGPoint) {
        guard let startPoint = mouseDownPoint,
              let startCell = mouseDownCell else {
            return
        }

        let distance = hypot(globalPoint.x - startPoint.x, globalPoint.y - startPoint.y)

        if distance > dragThreshold {
            // Enter dragging mode
            let currentCell = geometry.clampedCell(atGlobalPoint: globalPoint)
            interactionMode = .dragging(startCell: startCell, currentCell: currentCell)
            selectedRegion = GridRegion(from: startCell, to: currentCell)
        }
    }

    /// Handle mouse up (commit action or cancel).
    /// Returns the action to execute, or nil if cancelled.
    func handleMouseUp(at _: CGPoint) -> GridOverlayAction? {
        defer {
            reset()
        }

        switch interactionMode {
        case .hovering:
            // No mouse down occurred, no action
            return nil

        case let .pressing(startCell):
            // Click within threshold - commit 1x1
            guard mouseDownCell != nil else {
                // Started outside grid
                return .cancel
            }
            let region = GridRegion.single(startCell)
            return .commit(region: region, shouldSaveMemory: true, memorySize: GridSize(rows: 1, columns: 1))

        case let .dragging(startCell, currentCell):
            // Dragging - commit the selected region
            let region = GridRegion(from: startCell, to: currentCell)
            return .commit(region: region, shouldSaveMemory: true, memorySize: region.size)
        }
    }

    /// Handle hover-only commit (trigger key released without mouse interaction).
    func handleHoverCommit() -> GridOverlayAction? {
        defer {
            reset()
        }

        guard case .hovering = interactionMode,
              let region = selectedRegion else {
            return .cancel
        }

        // Hover commit does NOT save memory
        return .commit(region: region, shouldSaveMemory: false, memorySize: nil)
    }

    /// Handle cancel (Escape, timeout, or force close).
    func handleCancel() {
        reset()
    }

    // MARK: - Private Helpers

    private func reset() {
        hoveredCell = nil
        selectedRegion = nil
        interactionMode = .hovering
        mouseDownPoint = nil
        mouseDownCell = nil
    }

    // MARK: - Action Result

    enum GridOverlayAction {
        case commit(region: GridRegion, shouldSaveMemory: Bool, memorySize: GridSize?)
        case cancel
    }
}
