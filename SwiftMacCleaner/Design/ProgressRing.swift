//
//  ProgressRing.swift
//  SwiftMacCleaner
//

import SwiftUI

/// A ring that fills as work gets done.
struct ProgressRing: View {
    @Environment(\.theme) private var theme
    /// From 0 to 1.
    var fraction: Double
    var lineWidth: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Design.Surface.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, fraction)))
                .stroke(
                    AngularGradient(colors: [theme.accent.opacity(0.45), theme.accent], center: .center,
                                    startAngle: .zero, endAngle: .degrees(360 * max(fraction, 0.01))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
        }
        .rotationEffect(.degrees(-90))
        .padding(lineWidth / 2)
        .animation(.smooth, value: fraction)
        .accessibilityHidden(true)
    }
}
