//
//  MacDescription.swift
//  SwiftMacCleaner
//

import Foundation
import IOKit

/// What this Mac is, the way About This Mac names it: "MacBook Pro", "16-inch, Nov 2024", the chip,
/// the memory and the version of macOS. Read once; none of it changes while the app runs.
nonisolated struct MacDescription: Sendable, Equatable {
    /// "MacBook Pro", or the model identifier when macOS does not say more.
    var name: String
    /// What sets this one apart from others of its name: "16-inch, Nov 2024". Empty when macOS does not say.
    var edition: String
    /// "M4 Pro".
    var chip: String
    var memory: Int64
    /// "macOS 27.0.1".
    var system: String

    /// The line under the name: everything but the name, the parts macOS did not say left out.
    var detail: String {
        let memoryText = memory > 0 ? "\(memory / 1_073_741_824) GB memory" : ""
        return [edition, chip, memoryText, system].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    static let current = read()

    static func read() -> MacDescription {
        let product = productName() ?? ""
        let (name, edition) = split(product)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let patch = version.patchVersion > 0 ? ".\(version.patchVersion)" : ""
        return MacDescription(
            name: name.isEmpty ? (Sysctl.string("hw.model") ?? "Mac") : name,
            edition: edition,
            chip: (Sysctl.string("machdep.cpu.brand_string") ?? "").replacingOccurrences(of: "Apple ", with: ""),
            memory: Int64(clamping: ProcessInfo.processInfo.physicalMemory),
            system: "macOS \(version.majorVersion).\(version.minorVersion)\(patch)"
        )
    }

    /// "MacBook Pro (16-inch, Nov 2024)" as its name and what is in the brackets.
    static func split(_ product: String) -> (name: String, edition: String) {
        guard let open = product.firstIndex(of: "("), product.hasSuffix(")") else {
            return (product.trimmingCharacters(in: .whitespaces), "")
        }
        let name = product[..<open].trimmingCharacters(in: .whitespaces)
        let edition = product[product.index(after: open)..<product.index(before: product.endIndex)]
        return (name, String(edition))
    }

    /// The marketing name Apple silicon Macs keep in the device tree, as About This Mac shows it.
    private static func productName() -> String? {
        let product = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/product")
        guard product != 0 else { return nil }
        defer { IOObjectRelease(product) }
        guard let value = IORegistryEntryCreateCFProperty(product, "product-name" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? Data else { return nil }
        let text = String(decoding: value.prefix { $0 != 0 }, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
