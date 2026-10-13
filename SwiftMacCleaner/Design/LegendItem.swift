//
//  LegendItem.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One entry of a legend: the swatch, what it stands for, and how big it is.
struct LegendItem: View {
    let segment: UsageSegment

    var body: some View {
        HStack(spacing: Design.Spacing.small) {
            swatch
                .frame(width: Design.Size.legendSwatch, height: Design.Size.legendSwatch)
            Text(segment.label)
                .foregroundStyle(.quiet)
            Text(ByteFormat.string(segment.bytes))
                .monospacedDigit()
        }
        .font(.callout)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    @ContentBuilder
    private var swatch: some View {
        if segment.isRemainder {
            // An empty ring: a pale disc would be lost on the pale ground.
            Circle()
                .fill(Design.Surface.track)
                .strokeBorder(Design.Ink.tertiary)
        } else if segment.isStriped {
            Circle()
                .fill(Design.Surface.track)
                .overlay {
                    Hatch(color: segment.color)
                        .clipShape(.circle)
                }
        } else {
            Circle()
                .fill(segment.color)
        }
    }
}
