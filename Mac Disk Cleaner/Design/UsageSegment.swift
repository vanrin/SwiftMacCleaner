//
//  UsageSegment.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// One part of a disk or of a total, as a ring, a bar and a legend all draw it.
struct UsageSegment: Identifiable {
    let id: String
    var label: String
    var bytes: Int64
    var color: Color
    /// The empty remainder: drawn as the track, and as an outlined swatch in the legend.
    var isRemainder = false
    /// Drawn as stripes: space macOS may take back on its own.
    var isStriped = false
}
