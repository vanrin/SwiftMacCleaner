//
//  VitalRing.swift
//  SwiftMacCleaner
//

import SwiftUI

/// A ring filled as far as a reading goes, in the colour of how pressing the reading is. It starts
/// at the top and runs clockwise.
struct VitalRing: View {
    @Environment(\.theme) private var theme
    /// From 0 to 1.
    var fraction: Double
    var level = VitalLevel.normal
    var lineWidth: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Design.Surface.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, fraction)))
                .stroke(level.tint(in: theme), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
        .rotationEffect(.degrees(-90))
        .padding(lineWidth / 2)
        .accessibilityHidden(true)
    }
}
