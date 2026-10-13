//
//  MemoryReading.swift
//  SwiftMacCleaner
//

import Darwin
import Foundation

/// What the Mac's memory is doing: what is in use and as what, and how hard macOS has to work to
/// find more.
nonisolated struct MemoryReading: Equatable, Sendable {
    /// The kernel's own verdict, which is what the app goes by: a Mac uses most of its memory all
    /// the time, and only the kernel knows when that has become a struggle.
    enum Pressure: Int, Comparable, Sendable {
        case normal, warning, critical

        /// The kernel reports 1, 2 or 4.
        init(kernelLevel: Int) {
            self = kernelLevel >= 4 ? .critical : kernelLevel >= 2 ? .warning : .normal
        }

        static func < (lhs: Pressure, rhs: Pressure) -> Bool { lhs.rawValue < rhs.rawValue }

        var title: String {
            switch self {
            case .normal: "Normal"
            case .warning: "Tight"
            case .critical: "Critical"
            }
        }

        var detail: String {
            switch self {
            case .normal: "This Mac has room for more."
            case .warning: "macOS is squeezing memory to keep up."
            case .critical: "Apps are waiting on the disk for memory."
            }
        }
    }

    /// The kernel's page counts the reading is made from.
    struct Pages: Equatable, Sendable {
        var active: UInt64
        var wired: UInt64
        /// The pages the compressor itself takes up, not the ones it holds squeezed.
        var compressor: UInt64
        /// Pages that mirror files on the disk, which macOS gives up as soon as an app wants the room.
        var fileBacked: UInt64
    }

    /// The memory this Mac has.
    var total: Int64
    /// In use by apps right now.
    var active: Int64
    /// In use by the system, which cannot be moved out of the way.
    var wired: Int64
    /// Taken up by memory macOS has squeezed to make room.
    var compressed: Int64
    var cached: Int64
    /// Disk space standing in for memory.
    var swap: Int64
    /// From 0 to 1: what is left over of the share macOS counts as free.
    var pressure: Double
    var state: Pressure

    var used: Int64 { min(total, active + wired + compressed) }
    var available: Int64 { max(0, total - used) }

    var level: VitalLevel {
        switch state {
        case .normal: .normal
        case .warning: .raised
        case .critical: .high
        }
    }

    var summary: VitalSummary {
        VitalSummary(fraction: pressure, line: VitalFormat.memoryShare(used, of: total), level: level)
    }

    var facts: [VitalFact] {
        [
            VitalFact(title: "Swap", value: VitalFormat.memory(swap), detail: "Disk space standing in for memory."),
            VitalFact(title: "Cached", value: VitalFormat.memory(cached), detail: "Files kept for speed. Counts as available."),
        ]
    }

    init(total: Int64, active: Int64, wired: Int64, compressed: Int64, cached: Int64, swap: Int64, pressure: Double, state: Pressure) {
        self.total = total
        self.active = active
        self.wired = wired
        self.compressed = compressed
        self.cached = cached
        self.swap = swap
        self.pressure = pressure
        self.state = state
    }

    /// - Parameters:
    ///   - freePercent: The kernel's figure for how much memory is free, out of 100.
    ///   - kernelLevel: The kernel's pressure level: 1, 2 or 4.
    init(pages: Pages, pageSize: Int64, total: Int64, swap: Int64, freePercent: Int, kernelLevel: Int) {
        func bytes(_ pages: UInt64) -> Int64 { Int64(clamping: pages) * pageSize }
        self.init(total: total, active: bytes(pages.active), wired: bytes(pages.wired), compressed: bytes(pages.compressor),
                  cached: bytes(pages.fileBacked), swap: swap,
                  pressure: Double(100 - min(100, max(0, freePercent))) / 100, state: Pressure(kernelLevel: kernelLevel))
    }

    private static let host = mach_host_self()

    /// The reading right now. Nil when the kernel will not hand out its counts.
    static func current() -> MemoryReading? {
        var statistics = vm_statistics64()
        var length = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(length)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &length)
            }
        }
        var pageSize: vm_size_t = 0
        guard result == KERN_SUCCESS, host_page_size(host, &pageSize) == KERN_SUCCESS else { return nil }
        let pages = Pages(active: UInt64(statistics.active_count), wired: UInt64(statistics.wire_count),
                          compressor: UInt64(statistics.compressor_page_count), fileBacked: UInt64(statistics.external_page_count))
        return MemoryReading(
            pages: pages,
            pageSize: Int64(pageSize),
            total: Int64(clamping: ProcessInfo.processInfo.physicalMemory),
            swap: Sysctl.value("vm.swapusage", as: xsw_usage.self).map { Int64(clamping: $0.xsu_used) } ?? 0,
            freePercent: Sysctl.integer("kern.memorystatus_level") ?? 100,
            kernelLevel: Sysctl.integer("kern.memorystatus_vm_pressure_level") ?? 1
        )
    }
}
