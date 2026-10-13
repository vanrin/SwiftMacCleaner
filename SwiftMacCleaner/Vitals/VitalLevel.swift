//
//  VitalLevel.swift
//  SwiftMacCleaner
//

import Foundation

/// How pressing a reading is, which decides the colour of its ring and whether its tile carries a mark.
nonisolated enum VitalLevel: Int, Comparable, Sendable {
    case normal, raised, high

    static func < (lhs: VitalLevel, rhs: VitalLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}
