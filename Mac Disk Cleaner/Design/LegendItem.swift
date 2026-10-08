//
//  LegendItem.swift
//  Mac Disk Cleaner
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
                .foregroundStyle(.secondary)
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
            Circle()
                .fill(Design.Surface.track)
                .strokeBorder(Design.Surface.panelBorder)
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
