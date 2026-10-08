//
//  SpaceShare.swift
//  SwiftMacCleaner
//

import Foundation

/// How one size compares with another, as words and as a fraction.
nonisolated enum SpaceShare {
    /// "42%", or "<1%" for anything that would round to nothing.
    static func text(of size: Int64, in total: Int64) -> String {
        guard total > 0, size > 0 else { return "0%" }
        let percent = Double(size) / Double(total) * 100
        return percent < 1 ? "<1%" : "\(Int(percent.rounded()))%"
    }

    static func fraction(of size: Int64, in total: Int64) -> Double {
        total > 0 ? Double(size) / Double(total) : 0
    }
}
