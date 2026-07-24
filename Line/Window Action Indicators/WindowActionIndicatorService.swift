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

    func openAndUpdate(preparedResize: WindowResizeExecution.PreparedResize) {
        if Defaults[.hideOnNoSelection], preparedResize.action.direction == .noSelection {
            closeAll()
            return
        }

        if Defaults[.previewVisibility] {
            previewController.open(preparedResize: preparedResize)
        }
    }

    /// Bridge for callers that still hold a ResizeContext (settings previews, drag).
    func openAndUpdate(context: ResizeContext) {
        openAndUpdate(preparedResize: WindowResizeExecution.PreparedResize(context: context))
    }

    func closeAll() {
        previewController.close()
    }
}
