//
//  CPUTicks.swift
//  SwiftMacCleaner
//

import Darwin
import Foundation

/// What one core has spent its time on since the Mac started, in the kernel's ticks. The counters
/// are 32 bits wide and start again from zero when they run out, so only differences mean anything.
nonisolated struct CPUTicks: Equatable, Sendable {
    /// Programs, the ones given a low priority included.
    var user: UInt32
    var system: UInt32
    var idle: UInt32

    private static let host = mach_host_self()

    /// What the core spent between `earlier` and now, a counter that started again allowed for.
    func spent(since earlier: CPUTicks) -> (user: UInt64, system: UInt64, idle: UInt64) {
        (UInt64(user &- earlier.user), UInt64(system &- earlier.system), UInt64(idle &- earlier.idle))
    }

    /// Every core's counts right now, in the kernel's order. Empty when the kernel will not say.
    static func current() -> [CPUTicks] {
        var cores: natural_t = 0
        var info: processor_info_array_t?
        var length: mach_msg_type_number_t = 0
        guard host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &cores, &info, &length) == KERN_SUCCESS, let info else { return [] }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(length) * vm_size_t(MemoryLayout<integer_t>.stride))
        }
        return (0..<Int(cores)).map { core in
            let first = core * Int(CPU_STATE_MAX)
            func ticks(_ state: Int32) -> UInt32 { UInt32(bitPattern: info[first + Int(state)]) }
            return CPUTicks(user: ticks(CPU_STATE_USER) &+ ticks(CPU_STATE_NICE), system: ticks(CPU_STATE_SYSTEM), idle: ticks(CPU_STATE_IDLE))
        }
    }
}
