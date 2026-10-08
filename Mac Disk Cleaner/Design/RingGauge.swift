//
//  RingGauge.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// A ring split into what each part of a total is doing. It starts at the top and runs clockwise.
struct RingGauge: View {
    var segments: [UsageSegment]
    var total: Int64
    var lineWidth: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Design.Surface.track, lineWidth: lineWidth)
            ForEach(RingArc.arcs(for: segments, total: total)) { arc in
                Circle()
                    .trim(from: arc.start, to: arc.end)
                    .stroke(arc.color, style: stroke(striped: arc.isStriped))
            }
        }
        .rotationEffect(.degrees(-90))
        .padding(lineWidth / 2)
        .animation(.snappy, value: segments.map(\.bytes))
        .accessibilityHidden(true)
    }

    /// Stripes across the ring stand for space that is neither used nor free.
    private func stroke(striped: Bool) -> StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, lineCap: .butt, dash: striped ? [2, 3] : [])
    }
}
