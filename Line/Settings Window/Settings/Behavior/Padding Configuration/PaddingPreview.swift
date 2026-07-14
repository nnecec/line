//
//  PaddingPreview.swift
//  Line
//
//  Created by nnecec on 2024-02-01.
//

import SwiftUI

struct PaddingPreview: View {
    @Binding var model: PaddingConfiguration

    init(_ paddingModel: Binding<PaddingConfiguration>) {
        self._model = paddingModel
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                HStack(spacing: model.window / 2) {
                    blurredWindow()

                    VStack(spacing: model.window / 2) {
                        blurredWindow()
                        blurredWindow()
                    }
                }
                .padding(.top, model.totalTopPadding / 2)
                .padding(.bottom, model.bottom / 2)
                .padding(.leading, model.left / 2)
                .padding(.trailing, model.right / 2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .animation(.default, value: model)
    }

    private func blurredWindow() -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            }
    }
}
