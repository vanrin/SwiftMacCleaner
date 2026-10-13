//
//  VitalLegendItem.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One part of a bar in a reading's details: its colour, its name, and how much it comes to.
struct VitalLegendItem: View {
    let label: String
    let value: String
    var color = Color.clear
    /// The empty end of the bar, drawn as an outlined swatch.
    var isRemainder = false

    var body: some View {
        HStack(spacing: Design.Spacing.small) {
            Circle()
                .fill(isRemainder ? Design.Surface.track : color)
                .strokeBorder(isRemainder ? Design.Ink.tertiary : .clear)
                .frame(width: Design.Size.legendSwatch, height: Design.Size.legendSwatch)
            Text(label)
                .foregroundStyle(.quiet)
            Spacer(minLength: Design.Spacing.tight)
            Text(value)
                .bold()
                .monospacedDigit()
        }
        .font(.callout)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }
}
