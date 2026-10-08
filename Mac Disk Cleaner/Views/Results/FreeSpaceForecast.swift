//
//  FreeSpaceForecast.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// "Free after cleaning: 60 GB, then 98 GB", updating as boxes are ticked.
struct FreeSpaceForecast: View {
    let now: Int64
    let after: Int64

    var body: some View {
        HStack(spacing: Design.Spacing.medium) {
            Text("Free after cleaning")
                .foregroundStyle(.secondary)
            Text(ByteFormat.string(now))
                .foregroundStyle(.secondary)
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
                .accessibilityLabel("becomes")
            Text(ByteFormat.string(after))
                .bold()
                .contentTransition(.numericText())
                .animation(.default, value: after)
        }
        .font(Design.Typeface.tileBody)
        .monospacedDigit()
        .lineLimit(1)
        .padding(.horizontal, Design.Spacing.xLarge)
        .padding(.vertical, Design.Spacing.medium)
        .background {
            Capsule()
                .fill(Design.Surface.well)
                .strokeBorder(Design.Surface.panelBorder)
        }
        .accessibilityElement(children: .combine)
    }
}
