//
//  VitalSummary.swift
//  SwiftMacCleaner
//

import Foundation

/// What a tile of the menu bar popover says about one reading.
nonisolated struct VitalSummary: Equatable, Sendable {
    /// How far the ring is filled, from 0 to 1.
    var fraction: Double
    /// The line under the name.
    var line: String
    var level: VitalLevel

    /// The figure in the ring.
    var figure: String { VitalFormat.percent(fraction) }
}
