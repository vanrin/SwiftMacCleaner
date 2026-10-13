//
//  OrbFigure.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The figure in the middle of a `HeroOrb`, with a word under it saying what it counts.
struct OrbFigure: View {
    let value: String
    let caption: String

    var body: some View {
        VStack(spacing: 0) {
            Text(value)
                .font(Design.Typeface.orbFigure)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .animation(.default, value: value)
            Text(caption)
                .font(Design.Typeface.orbCaption)
                .foregroundStyle(.quiet)
        }
    }
}
