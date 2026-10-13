//
//  VitalFactTile.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One figure of a reading's details on a tile of its own: what it is, the figure, and a sentence.
struct VitalFactTile: View {
    let fact: VitalFact

    var body: some View {
        GlassPanel(cornerRadius: Design.Radius.tile) {
            VStack(alignment: .leading, spacing: Design.Spacing.tight) {
                HStack(alignment: .firstTextBaseline, spacing: Design.Spacing.small) {
                    Text(fact.title)
                    Spacer(minLength: 0)
                    Text(fact.value)
                        .monospacedDigit()
                }
                .font(.headline)
                .lineLimit(1)
                Text(fact.detail)
                    .font(.callout)
                    .foregroundStyle(.quiet)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Design.Spacing.medium)
            // Tiles in a row are as tall as the tallest of them.
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .accessibilityElement(children: .combine)
    }
}
