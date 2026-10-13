//
//  VitalFormat.swift
//  SwiftMacCleaner
//

import Foundation

/// How the menu bar's readings are written: shares, memory and stretches of time.
nonisolated enum VitalFormat {
    /// The interface is English, so figures are written the English way whatever the Mac's region.
    private static let locale = Locale(identifier: "en_US")

    private static func number(_ value: Double, decimals: Int) -> String {
        value.formatted(.number.precision(.fractionLength(decimals)).locale(locale))
    }

    /// A share from 0 to 1 as "38%".
    static func percent(_ fraction: Double, decimals: Int = 0) -> String {
        "\(number(max(0, fraction) * 100, decimals: decimals))%"
    }

    /// Memory in binary units under their everyday names, the way macOS states it: a Mac with
    /// "24 GB" has 24 times 2 to the 30th bytes. Disk sizes are decimal, and `ByteFormat` writes those.
    static func memory(_ bytes: Int64, decimals: Int = 1) -> String {
        let megabytes = Double(max(bytes, 0)) / 1_048_576
        if megabytes >= 1024 { return "\(number(megabytes / 1024, decimals: decimals)) GB" }
        return megabytes >= 1 ? "\(number(megabytes, decimals: 0)) MB" : "\(number(megabytes * 1024, decimals: 0)) KB"
    }

    /// The memory a Mac has, which is a round figure: "24 GB", not "24.0 GB".
    static func installedMemory(_ bytes: Int64) -> String {
        let gigabytes = Double(max(bytes, 0)) / 1_073_741_824
        let isRound = abs(gigabytes - gigabytes.rounded()) < 0.05
        return "\(number(gigabytes, decimals: isRound ? 0 : 1)) GB"
    }

    /// "16.0 of 24 GB".
    static func memoryShare(_ part: Int64, of installed: Int64) -> String {
        "\(number(Double(max(part, 0)) / 1_073_741_824, decimals: 1)) of \(installedMemory(installed))"
    }

    /// Minutes as hours and minutes on a clock face: "5:10", "0:48".
    static func clock(minutes: Int) -> String {
        let minutes = max(0, minutes)
        return "\(minutes / 60):\((minutes % 60).formatted(.number.precision(.integerLength(2)).locale(locale)))"
    }

    /// How long something has gone on, in its largest unit: "6 days", "1 hour", "40 minutes".
    static func span(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(0, seconds) / 60)
        let (count, unit) = minutes >= 1440 ? (minutes / 1440, "day") : minutes >= 60 ? (minutes / 60, "hour") : (minutes, "minute")
        return "\(count) \(unit)\(count == 1 ? "" : "s")"
    }

    /// A count with its thousands set apart: "1,000".
    static func count(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }
}
