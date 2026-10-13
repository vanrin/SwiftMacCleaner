//
//  ProcessUsage.swift
//  SwiftMacCleaner
//

import Darwin
import Foundation

/// What one running program has used so far, as the kernel counts it.
///
/// Only this user's programs can be asked. One that belongs to root or to someone else keeps its
/// figures to itself, so the lists made from these are the user's own apps and helpers.
nonisolated struct ProcessUsage: Equatable, Sendable {
    var pid: pid_t
    /// Where the program's executable is.
    var path: String
    /// Processor time since it started, in nanoseconds.
    var cpuTime: UInt64
    /// The memory that is this program's alone, the figure Activity Monitor shows.
    var memory: Int64
    /// When it started, on the kernel's clock. A different value under the same number is a different program.
    var startedAt: UInt64

    /// Every program of this user's that is running. `knownPaths` saves asking again where a program
    /// that was already seen lives; it takes a few thousandths of a second all told.
    static func all(knownPaths: [pid_t: ProcessUsage] = [:]) -> [ProcessUsage] {
        // Room for more programs than a Mac runs; the call says how much of it was filled.
        var pids = [pid_t](repeating: 0, count: 16_384)
        let filled = Int(proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size)))
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        let (numerator, denominator) = (UInt64(max(timebase.numer, 1)), UInt64(max(timebase.denom, 1)))

        var usages: [ProcessUsage] = []
        for pid in pids.prefix(max(0, filled)) where pid > 0 {
            var info = rusage_info_v2()
            let result = withUnsafeMutablePointer(to: &info) { pointer in
                pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V2, $0) }
            }
            guard result == 0 else { continue }
            let path: String
            if let known = knownPaths[pid], known.startedAt == info.ri_proc_start_abstime {
                path = known.path
            } else {
                var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
                guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { continue }
                path = String(cString: buffer)
            }
            // The kernel counts processor time on its own clock, which on Apple's chips does not tick in nanoseconds.
            let ticks = info.ri_user_time &+ info.ri_system_time
            usages.append(ProcessUsage(pid: pid, path: path, cpuTime: ticks / denominator * numerator + ticks % denominator * numerator / denominator,
                                       memory: Int64(clamping: info.ri_phys_footprint), startedAt: info.ri_proc_start_abstime))
        }
        return usages
    }
}
