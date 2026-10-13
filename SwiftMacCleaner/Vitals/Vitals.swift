//
//  Vitals.swift
//  SwiftMacCleaner
//

import Foundation

/// The Mac's readings at one moment. A part is nil while it has yet to be read, and the battery's
/// stays nil on a Mac that has none.
nonisolated struct Vitals: Equatable, Sendable {
    var cpu: CPUReading?
    var memory: MemoryReading?
    var battery: BatteryReading?
    /// The apps using the most processor time, and the most memory.
    var byCPU: [Consumer] = []
    var byMemory: [Consumer] = []

    /// What the tile of one reading says, or nil while there is nothing to say yet.
    func summary(of kind: VitalKind) -> VitalSummary? {
        switch kind {
        case .cpu: cpu?.summary
        case .memory: memory?.summary
        case .battery: battery?.summary
        }
    }
}
