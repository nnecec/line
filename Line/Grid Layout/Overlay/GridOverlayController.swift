//
//  GridOverlayController.swift
//  Line
//
//  Manages the grid overlay window/panel.
//  Created by nnecec on 2024-12-30.

//

import Scribe
import SwiftUI

@Loggable
@MainActor
final class GridOverlayController {
    private var controller: NSWindowController?
    private(set) var viewModel: GridOverlayViewModel?

    /// Open the grid overlay on the specified screen.
    func open(
        screen _: NSScreen,
        geometry: GridGeometry,
        template: GridTemplate,
        rememberedSize: GridSize
    ) {
        close()

        let viewModel = GridOverlayViewModel(geometry: geometry, rememberedSize: rememberedSize)
        self.viewModel = viewModel

        let panel = ActivePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        controller = .init(window: panel)

        panel.ignoresMouseEvents = false
        panel.collectionBehavior = .canJoinAllSpaces
        panel.isOpaque = false
        // Shadow is drawn by GridOverlayView so it stays in sync with the glass edge.
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.level = NSWindow.Level(NSWindow.Level.screenSaver.rawValue)
        let hostingView = NSHostingView(
            rootView: GridOverlayView(
                viewModel: viewModel,
                geometry: geometry,
                template: template
            )
        )
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
        panel.setFrame(geometry.displayBounds, display: true)
        panel.orderFrontRegardless()

        log.debug("Grid overlay opened")
    }

    /// Close the grid overlay immediately.
    func close() {
        guard controller != nil else { return }

        controller?.window?.orderOut(nil)
        controller?.close()
        controller = nil
        viewModel = nil

        log.debug("Grid overlay closed")
    }

    /// Check if the overlay is currently open.
    var isOpen: Bool {
        controller != nil
    }
}
