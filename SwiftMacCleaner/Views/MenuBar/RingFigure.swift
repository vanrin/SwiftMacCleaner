//
//  RingFigure.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The figure in the middle of a details ring, with the word for what it measures.
struct RingFigure: View {
    let figure: String
    let caption: String

    var body: some View {
        VStack(spacing: 0) {
            Text(figure)
                .font(Design.Typeface.detailFigure)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Design.Size.detailRingLine + Design.Spacing.tight)
        .accessibilityElement(children: .combine)
    }
}
