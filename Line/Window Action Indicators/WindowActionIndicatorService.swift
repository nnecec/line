//
//  WindowActionIndicatorService.swift
//  Line
//
//  Created by nnecec on 2026-01-19.
//

import Defaults

@MainActor
final class WindowActionIndicatorService {
    private let previewController = PreviewController()

    func openAndUpdate(context: ResizeContext) {
        if Defaults[.hideOnNoSelection], context.action.direction == .noSelection {
            closeAll()
            return
        }

        if Defaults[.previewVisibility] {
            previewController.open(context: context)
        }
    }

    func closeAll() {
        previewController.close()
    }
}
