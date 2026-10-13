//
//  Heat.swift
//  SwiftMacCleaner
//

import Foundation

/// How warm macOS says the Mac is running. It hands out no temperature, only whether it has begun to
/// hold things back, so that is what the app reports.
nonisolated enum Heat: Int, Comparable, Sendable {
    case normal, raised, serious, critical

    init(_ state: ProcessInfo.ThermalState) {
        self = switch state {
        case .nominal: .normal
        case .fair: .raised
        case .serious: .serious
        case .critical: .critical
        @unknown default: .normal
        }
    }

    static func < (lhs: Heat, rhs: Heat) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .normal: "Normal"
        case .raised: "Raised"
        case .serious: "High"
        case .critical: "Critical"
        }
    }

    /// The line on the CPU tile.
    var line: String {
        switch self {
        case .normal: "Heat: normal"
        case .raised: "Heat: raised"
        case .serious: "Running hot"
        case .critical: "Overheating"
        }
    }

    var detail: String {
        switch self {
        case .normal: "macOS is not slowing anything down."
        case .raised: "Warmer than usual. Nothing is slowed down yet."
        case .serious: "macOS is slowing things down to cool off."
        case .critical: "This Mac needs to cool down now."
        }
    }
}
