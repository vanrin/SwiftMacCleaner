//
//  RingArc.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Where one segment of a `RingGauge` starts and ends, as fractions of the full circle.
struct RingArc: Identifiable {
    let id: String
    var start: Double
    var end: Double
    var color: Color
    var isStriped: Bool

    /// Lays the segments end to end around the ring, leaving out the remainder, which the track already shows.
    static func arcs(for segments: [UsageSegment], total: Int64) -> [RingArc] {
        let total = Double(max(total, 1))
        var start = 0.0
        var arcs: [RingArc] = []
        for segment in segments where !segment.isRemainder {
            let end = min(1, start + Double(max(segment.bytes, 0)) / total)
            arcs.append(RingArc(id: segment.id, start: start, end: end, color: segment.color, isStriped: segment.isStriped))
            start = end
        }
        return arcs
    }
}
