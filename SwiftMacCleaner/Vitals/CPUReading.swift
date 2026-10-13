//
//  CPUReading.swift
//  SwiftMacCleaner
//

import Darwin
import Foundation

/// What the processor is doing: how busy each core is, who the time goes to, and how warm macOS
/// says the Mac is.
nonisolated struct CPUReading: Equatable, Sendable {
    /// Above this share of every core, kept up for about a minute, the Mac counts as busy.
    static let busyLoad = 0.7

    /// The chip's name, such as "Apple M4 Pro".
    var chip: String
    var cores: [CPUCore]
    /// The share of all the cores' time that went to programs, and to the system, from 0 to 1.
    var user: Double
    var system: Double
    /// How many threads wanted a core at once, averaged by the kernel over the last minute. It is
    /// what tells a minute of work from the moment a page loads.
    var loadAverage: Double
    var heat: Heat
    /// When the Mac was last started.
    var startedAt: Date?

    var load: Double { min(1, user + system) }
    var idle: Double { max(0, 1 - user - system) }

    var isBusy: Bool {
        load >= Self.busyLoad && loadAverage >= Self.busyLoad * Double(max(cores.count, 1))
    }

    var level: VitalLevel {
        if heat >= .serious { .high } else if isBusy { .raised } else { .normal }
    }

    var summary: VitalSummary { VitalSummary(fraction: load, line: heat.line, level: level) }

    /// The cores by kind, the fast ones first, leaving out a kind this Mac has none of.
    var coreGroups: [CoreGroup] {
        CPUCore.Kind.allCases.compactMap { kind in
            let cores = cores.filter { $0.kind == kind }
            return cores.isEmpty ? nil : CoreGroup(kind: kind, cores: cores)
        }
    }

    func facts(now: Date = .now) -> [VitalFact] {
        var facts = [VitalFact(title: "Heat", value: heat.title, detail: heat.detail)]
        if let startedAt {
            let since = startedAt.formatted(.dateTime.day().month(.wide).hour().minute())
            facts.append(VitalFact(title: "Uptime", value: VitalFormat.span(now.timeIntervalSince(startedAt)), detail: "Running since \(since)."))
        }
        return facts
    }

    /// How each core spent the time between two counts, and the share of all of it that went to
    /// programs and to the system. Nil when the counts do not belong together or no time has passed.
    static func shares(from earlier: [CPUTicks], to later: [CPUTicks]) -> (cores: [Double], user: Double, system: Double)? {
        guard !later.isEmpty, earlier.count == later.count else { return nil }
        var cores: [Double] = []
        var user: UInt64 = 0
        var system: UInt64 = 0
        var total: UInt64 = 0
        for (before, after) in zip(earlier, later) {
            let spent = after.spent(since: before)
            let all = spent.user + spent.system + spent.idle
            cores.append(all == 0 ? 0 : Double(spent.user + spent.system) / Double(all))
            user += spent.user
            system += spent.system
            total += all
        }
        guard total > 0 else { return nil }
        return (cores, Double(user) / Double(total), Double(system) / Double(total))
    }

    /// The reading for the time between two counts, with what macOS says about the chip, the heat
    /// and the last start.
    static func current(from earlier: [CPUTicks], to later: [CPUTicks]) -> CPUReading? {
        guard let shares = shares(from: earlier, to: later) else { return nil }
        let kinds = CoreLayout.kinds
        var averages = [Double](repeating: 0, count: 3)
        getloadavg(&averages, 3)
        return CPUReading(
            chip: chip,
            cores: shares.cores.enumerated().map { number, load in
                CPUCore(id: number, kind: kinds.indices.contains(number) ? kinds[number] : .plain, load: load)
            },
            user: shares.user,
            system: shares.system,
            loadAverage: averages[0],
            heat: Heat(ProcessInfo.processInfo.thermalState),
            startedAt: Sysctl.value("kern.boottime", as: timeval.self).map { Date(timeIntervalSince1970: TimeInterval($0.tv_sec)) }
        )
    }

    private static let chip = Sysctl.string("machdep.cpu.brand_string") ?? "Processor"
}
