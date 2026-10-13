//
//  VitalKind.swift
//  SwiftMacCleaner
//

import Foundation

/// The readings on the menu bar popover, in the order of their tiles.
nonisolated enum VitalKind: String, CaseIterable, Identifiable, Sendable {
    case cpu, memory, battery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "Memory"
        case .battery: "Battery"
        }
    }
}
