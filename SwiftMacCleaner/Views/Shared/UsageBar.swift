//
//  UsageBar.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One horizontal bar for a whole disk, split into what each part of it is doing.
struct UsageBar: View {
    /// The parts to draw, in order. The remainder is left out: the empty end of the bar already shows it.
    var segments: [UsageSegment]
    var total: Int64
    var height = Design.Spacing.medium
    /// The empty part of the bar. A bar on a dark surface is given a pale one.
    var track = Design.Surface.track

    var body: some View {
        ProportionalRow(total: Double(max(total, 1))) {
            ForEach(segments) { segment in
                Rectangle()
                    .fill(segment.isStriped ? AnyShapeStyle(track) : AnyShapeStyle(segment.color))
                    .overlay {
                        Hatch(color: segment.color)
                            .opacity(segment.isStriped ? 1 : 0)
                    }
                    .layoutValue(key: ProportionKey.self, value: Double(max(segment.bytes, 0)))
            }
        }
        .frame(height: height)
        .background(track)
        .clipShape(.capsule)
        .animation(.snappy, value: segments.map(\.bytes))
        .accessibilityHidden(true)
    }
}
