//
//  CoreLayout.swift
//  SwiftMacCleaner
//

import Foundation
import IOKit

/// Which of the processor's cores are the fast ones and which the frugal ones.
nonisolated enum CoreLayout {
    /// The kind of each core, in the kernel's order. It never changes while the Mac is on.
    static let kinds = read()

    private static func read() -> [CPUCore.Kind] {
        let count = Sysctl.integer("hw.logicalcpu") ?? ProcessInfo.processInfo.processorCount
        let efficiency = Sysctl.integer("hw.perflevel1.logicalcpu") ?? 0
        let fromChip = deviceTreeKinds(count: count)
        return fromChip.contains { $0 != .plain } ? fromChip : assumed(count: count, efficiency: efficiency)
    }

    /// Without the chip's own word for it, the frugal cores are taken to come first, as they do on
    /// every Apple chip so far. A Mac that has only one kind has plain cores.
    static func assumed(count: Int, efficiency: Int) -> [CPUCore.Kind] {
        guard efficiency > 0, efficiency < count else { return Array(repeating: .plain, count: max(count, 0)) }
        return Array(repeating: .efficiency, count: efficiency) + Array(repeating: .performance, count: count - efficiency)
    }

    /// What the chip's description says about each core: its number and the cluster it belongs to.
    private static func deviceTreeKinds(count: Int) -> [CPUCore.Kind] {
        var kinds = [CPUCore.Kind](repeating: .plain, count: max(count, 0))
        let cpus = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/cpus")
        guard cpus != 0 else { return kinds }
        defer { IOObjectRelease(cpus) }
        var children: io_iterator_t = 0
        guard IORegistryEntryGetChildIterator(cpus, kIODeviceTreePlane, &children) == KERN_SUCCESS else { return kinds }
        defer { IOObjectRelease(children) }
        while case let core = IOIteratorNext(children), core != 0 {
            defer { IOObjectRelease(core) }
            func property(_ name: String) -> Any? {
                IORegistryEntryCreateCFProperty(core, name as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
            }
            guard let number = (property("logical-cpu-id") as? NSNumber)?.intValue, kinds.indices.contains(number),
                  let cluster = (property("cluster-type") as? Data)?.first else { continue }
            kinds[number] = switch cluster {
            case UInt8(ascii: "E"): .efficiency
            case UInt8(ascii: "P"): .performance
            default: .plain
            }
        }
        return kinds
    }
}
