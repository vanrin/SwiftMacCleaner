//
//  CoreGroup.swift
//  SwiftMacCleaner
//

import Foundation

/// The cores of one kind, which the CPU details draw side by side.
nonisolated struct CoreGroup: Identifiable, Equatable, Sendable {
    var kind: CPUCore.Kind
    var cores: [CPUCore]

    var id: CPUCore.Kind { kind }
    var caption: String { kind.caption(count: cores.count) }
    /// From 0 to 1.
    var busiest: Double { cores.map(\.load).max() ?? 0 }
    var average: Double { cores.isEmpty ? 0 : cores.reduce(0) { $0 + $1.load } / Double(cores.count) }
}
