//
//  Sysctl.swift
//  SwiftMacCleaner
//

import Darwin
import Foundation

/// The kernel's own figures, asked for by name.
nonisolated enum Sysctl {
    /// A figure the kernel keeps as a fixed-size value: a number, or one of its small structures.
    static func value<Value>(_ name: String, as type: Value.Type) -> Value? {
        var size = MemoryLayout<Value>.size
        let pointer = UnsafeMutablePointer<Value>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        guard sysctlbyname(name, pointer, &size, nil, 0) == 0, size == MemoryLayout<Value>.size else { return nil }
        return pointer.pointee
    }

    /// A whole number, whichever of the two widths the kernel keeps it in.
    static func integer(_ name: String) -> Int? {
        if let wide = value(name, as: Int64.self) { return Int(wide) }
        return value(name, as: Int32.self).map(Int.init)
    }

    static func string(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }
}
