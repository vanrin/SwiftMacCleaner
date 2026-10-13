//
//  LoadShare.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One part of the processor's time beside the CPU ring: its colour on the ring, its share, its name.
struct LoadShare: View {
    let color: Color
    /// From 0 to 1, or nil until the first reading is in.
    let share: Double?
    let label: String

    var body: some View {
        HStack(spacing: Design.Spacing.medium) {
            Capsule()
                .fill(color)
                .frame(width: Design.Size.legendBarWidth, height: Design.Size.legendBarHeight)
            VStack(alignment: .leading, spacing: 0) {
                Text(share.map { VitalFormat.percent($0, decimals: 1) } ?? "–")
                    .font(.title3)
                    .bold()
                    .monospacedDigit()
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.quiet)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
