//
//  GridModeCoordinator.swift
//  Line
//
//  Created by Claude on 2026-07-08.

import Defaults
import Scribe
import SwiftUI

/// Coordinates grid mode interaction for visual window layout selection.
///
/// Grid mode is a complete, self-contained interaction flow:
/// 1. Open grid overlay centered at mouse position
/// 2. User hovers over grid cells to preview layouts
/// 3. User commits selection or cancels
/// 4. Apply window action and close
///
/// This coordinator is independent of WindowActionSession and uses its own Prepared Resize.
@Loggable
@MainActor
final class GridModeCoordinator {
    // MARK: - Dependencies

    private let indicatorService: WindowActionIndicatorService

    // MARK: - Internal State

    private let gridOverlayController = GridOverlayController()
    private var gridMouseObserver: GridMouseObserver?
    private var gridContext: GridContext?
    /// Latest hover Prepared Resize; commit applies this snapshot (release-style).
    private var hoverPreparedResize: WindowResizeExecution.PreparedResize?

    private(set) var isActive: Bool = false

    // MARK: - Initialization

    init(indicatorService: WindowActionIndicatorService) {
        self.indicatorService = indicatorService
    }

    // MARK: - Public Interface

    /// Open grid mode for layout selection.
    /// - Parameters:
    ///   - window: Target window to resize (optional)
    ///   - initialMousePosition: Mouse position when grid mode was triggered
    ///   - onComplete: Called when grid mode closes (committed or cancelled)
    /// - Returns: Whether grid mode opened successfully.
    func open(
        window: Window?,
        initialMousePosition: CGPoint,
        onComplete: @escaping () -> ()
    ) async -> OpenResult {
        log.info("Entering grid mode")

        // Target screen is always the screen with mouse cursor in grid mode
        guard let screen = NSScreen.screenWithMouse else {
            log.error("No screen found at mouse position")
            onComplete()
            return .failed
        }

        let preparedResize = await WindowResizeExecution.bootstrap(
            window: window,
            screen: screen,
            initialMousePosition: initialMousePosition
        )
        hoverPreparedResize = nil

        // Get grid template and remembered size
        let configManager = GridConfigurationManager.shared
        let template = configManager.template(for: screen)
        let bundleId = window?.nsRunningApplication?.bundleIdentifier
        let rememberedSize = configManager.rememberedSize(bundleId: bundleId, screen: screen)

        // Create grid geometry centered at the trigger position
        let displayBounds = GridGeometry.thumbnailBounds(
            centeredAt: initialMousePosition,
            screenFrame: screen.frame,
            workingBounds: preparedResize.paddedBounds
        )
        let geometry = GridGeometry(
            screenFrame: screen.frame,
            workingBounds: preparedResize.paddedBounds,
            template: template,
            displayBounds: displayBounds
        )

        // Store grid context with snapshotted window properties for hover previews.
        gridContext = GridContext(
            window: window,
            screen: screen,
            geometry: geometry,
            template: template,
            bundleId: bundleId,
            windowProperties: preparedResize.windowProperties,
            record: preparedResize.record
        )

        // Open grid overlay
        gridOverlayController.open(
            screen: screen,
            geometry: geometry,
            template: template,
            rememberedSize: rememberedSize
        )

        // Start grid mouse observer with callbacks
        let mouseObserver = GridMouseObserver(
            submitCallback: { [weak self] action in
                Task { @MainActor in
                    await self?.handleGridAction(action, onComplete: onComplete)
                }
            },
            previewCallback: { [weak self] region in
                self?.updateGridPreview(for: region)
            }
        )
        gridMouseObserver = mouseObserver
        if let viewModel = gridOverlayController.viewModel {
            mouseObserver.start(viewModel: viewModel)
        }

        isActive = true

        log.info("Grid mode opened")
        return .opened
    }

    /// Commit the current hover selection when the trigger key is released.
    func commitHoveredSelection(onComplete: @escaping () -> ()) async {
        guard let action = gridMouseObserver?.hoverCommitAction() else {
            close(reason: .cancelled)
            onComplete()
            return
        }

        await handleGridAction(action, onComplete: onComplete)
    }

    /// Close grid mode immediately.
    func close(reason: CloseReason) {
        log.info("Closing grid mode (reason: \(reason.rawValue))")
        gridOverlayController.close()
        indicatorService.closeAll()
        gridMouseObserver?.stop()
        gridMouseObserver = nil
        gridContext = nil
        hoverPreparedResize = nil

        isActive = false
    }

    // MARK: - Private Implementation

    /// Update the full-screen window preview for the currently hovered grid region.
    ///
    /// Uses snapshotted window properties from grid open — no AX `resolveState` per hover.
    /// Commit applies the current hover Prepared Resize (same as session release commit).
    private func updateGridPreview(for region: GridRegion?) {
        guard let context = gridContext, let region else {
            hoverPreparedResize = nil
            indicatorService.closeAll()
            return
        }

        let preparedResize = context.preparePreview(for: region)
        hoverPreparedResize = preparedResize
        indicatorService.openAndUpdate(preparedResize: preparedResize)
    }

    /// Handle grid overlay action (commit or cancel).
    private func handleGridAction(
        _ action: GridOverlayViewModel.GridOverlayAction,
        onComplete: @escaping () -> ()
    ) async {
        guard let context = gridContext else {
            log.error("Grid action received but no grid context exists")
            close(reason: .cancelled)
            onComplete()
            return
        }

        switch action {
        case .cancel:
            log.info("Grid action cancelled")
            close(reason: .cancelled)
            onComplete()

        case let .commit(region, shouldSaveMemory, memorySize):
            log.info("Grid action committed: region=\(region), saveMemory=\(shouldSaveMemory)")
            await commitGridLayout(
                region: region,
                shouldSaveMemory: shouldSaveMemory,
                memorySize: memorySize,
                context: context
            )
            onComplete()
        }
    }

    /// Commit the grid layout and apply to window using the current Prepared Resize.
    private func commitGridLayout(
        region: GridRegion,
        shouldSaveMemory: Bool,
        memorySize: GridSize?,
        context: GridContext
    ) async {
        // Prefer the hover snapshot so preview and commit match; rebuild only if missing.
        let preparedResize = hoverPreparedResize ?? context.preparePreview(for: region)

        // Close overlay immediately
        close(reason: .committed)

        guard context.window != nil else {
            log.warn("No target window for grid layout")
            return
        }

        // Apply action — release-style commit of current Prepared Resize
        do {
            let result = try await WindowActionEngine.shared.apply(preparedResize: preparedResize)
            if result.success {
                log.info("Grid layout applied successfully")

                // Save memory on success
                if shouldSaveMemory, let memorySize {
                    GridConfigurationManager.shared.saveSize(
                        memorySize,
                        bundleId: context.bundleId,
                        screen: context.screen
                    )
                    log.info("Saved grid memory: \(memorySize)")
                }
            } else {
                log.warn("Grid layout apply returned didApply=false")
            }
        } catch {
            log.error("Failed to apply grid layout: \(ApplicationLogPrivacy.errorDescription(error))")
        }
    }

    // MARK: - Types

    enum CloseReason: String {
        case cancelled
        case committed
    }

    enum OpenResult: Equatable {
        case opened
        case failed
    }
}
