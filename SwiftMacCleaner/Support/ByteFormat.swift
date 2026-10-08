//
//  ByteFormat.swift
//  SwiftMacCleaner
//

import Foundation

nonisolated enum ByteFormat {
    /// Decimal units, the way Finder reports sizes: "14.2 GB", "380 MB".
    static func string(_ bytes: Int64) -> String {
        let units = ["KB", "MB", "GB", "TB"]
        var value = Double(max(bytes, 0)) / 1000
        var index = 0
        while value >= 999.5, index < units.count - 1 {
            value /= 1000
            index += 1
        }
        return String(format: index >= 2 ? "%.1f %@" : "%.0f %@", value, units[index])
    }
}
