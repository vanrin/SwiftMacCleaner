//
//  VitalsDemoData.swift
//  SwiftMacCleaner
//

import Foundation

#if DEBUG
/// Made-up readings for the demo screens, so the menu bar looks the same whatever this Mac is doing:
/// a MacBook Pro on a quiet afternoon, and the states a quiet afternoon never shows.
nonisolated enum VitalsDemoData {
    private static let gigabyte: Int64 = 1_073_741_824

    /// - Parameter state: `normal`, or one of `busy`, `hot`, `tight`, `full`, `charging`, `battery`,
    ///   `low`, `desktop` and `empty`, which changes the one reading it names.
    static func vitals(_ state: String = "normal") -> Vitals {
        var vitals = Vitals(cpu: cpu(), memory: memory(), battery: battery(), byCPU: byCPU, byMemory: byMemory)
        switch state {
        case "busy":
            vitals.cpu = cpu(performance: [96, 91, 88, 84, 80, 77, 73, 70, 66, 61], efficiency: [92, 88, 85, 81], user: 0.62, system: 0.16, loadAverage: 13.4)
        case "hot":
            vitals.cpu = cpu(performance: [82, 77, 71, 66, 60, 58, 52, 47, 44, 40], efficiency: [88, 84, 79, 75], user: 0.5, system: 0.14, loadAverage: 8.2, heat: .serious)
        case "tight":
            vitals.memory = memory(active: 11.6, wired: 3.9, compressed: 5.8, swap: 4.1, pressure: 0.72, state: .warning)
        case "full":
            vitals.memory = memory(active: 12.9, wired: 4.1, compressed: 6.4, swap: 9.6, pressure: 0.94, state: .critical)
        case "charging":
            vitals.battery = battery(charge: 0.62, state: .charging, minutesToFull: 48)
        case "battery":
            vitals.battery = battery(charge: 0.74, state: .onBattery, minutesLeft: 310)
        case "low":
            vitals.battery = battery(charge: 0.12, state: .onBattery, minutesLeft: 35)
        case "desktop":
            vitals.battery = nil
        case "empty":
            vitals = Vitals(battery: battery())
        default:
            break
        }
        return vitals
    }

    /// The frugal cores come first in the kernel's count, as on the chip the figures are from.
    private static func cpu(performance: [Double] = [22, 18, 9, 6, 4, 3, 2, 2, 1, 1], efficiency: [Double] = [48, 41, 36, 30],
                            user: Double = 0.096, system: Double = 0.061, loadAverage: Double = 2.3, heat: Heat = .normal) -> CPUReading {
        let cores = efficiency.map { (CPUCore.Kind.efficiency, $0) } + performance.map { (CPUCore.Kind.performance, $0) }
        return CPUReading(
            chip: "Apple M4 Pro",
            cores: cores.enumerated().map { number, core in CPUCore(id: number, kind: core.0, load: core.1 / 100) },
            user: user, system: system, loadAverage: loadAverage, heat: heat,
            startedAt: Date.now.addingTimeInterval(-6 * 86_400 - 5_400)
        )
    }

    private static func memory(active: Double = 6.92, wired: Double = 3.42, compressed: Double = 5.67, swap: Double = 2.2,
                               pressure: Double = 0.38, state: MemoryReading.Pressure = .normal) -> MemoryReading {
        func bytes(_ gigabytes: Double) -> Int64 { Int64(gigabytes * Double(gigabyte)) }
        return MemoryReading(total: 24 * gigabyte, active: bytes(active), wired: bytes(wired), compressed: bytes(compressed),
                             cached: bytes(5), swap: bytes(swap), pressure: pressure, state: state)
    }

    private static func battery(charge: Double = 1, state: BatteryReading.State = .charged, minutesLeft: Int? = nil,
                                minutesToFull: Int? = nil) -> BatteryReading {
        BatteryReading(charge: charge, state: state, minutesLeft: minutesLeft, minutesToFull: minutesToFull,
                       adapterWatts: state == .onBattery ? nil : 140, cycles: 310, designCycles: 1000, capacity: 7548, designCapacity: 8579)
    }

    private static let finder = "/System/Library/CoreServices/Finder.app"

    private static func app(_ name: String, _ bundleID: String, cpu: Double? = nil, megabytes: Double = 0) -> Consumer {
        Consumer(id: "/Applications/\(name).app", name: name, cpu: cpu, memory: Int64(megabytes * 1_048_576), bundleID: bundleID, isSystem: false)
    }

    private static let byCPU = [
        app("Warp", "dev.warp.Warp-Stable", cpu: 12.7),
        app("Google Chrome", "com.google.Chrome", cpu: 9),
        app("Telegram", "ru.keepcoder.Telegram", cpu: 6.5),
        Consumer(id: finder, name: "Finder", cpu: 0.7, memory: 0, isSystem: true),
        Consumer(id: "/System/Library/CoreServices/WindowManager.app/Contents/MacOS/WindowManager", name: "WindowManager", cpu: 0.3, memory: 0, isSystem: true),
    ]

    private static let byMemory = [
        app("Xcode", "com.apple.dt.Xcode", megabytes: 3.96 * 1024),
        app("Warp", "dev.warp.Warp-Stable", megabytes: 2.47 * 1024),
        app("Google Chrome", "com.google.Chrome", megabytes: 1.15 * 1024),
        app("Telegram", "ru.keepcoder.Telegram", megabytes: 940),
        Consumer(id: finder, name: "Finder", memory: 416 * 1_048_576, isSystem: true),
    ]
}
#endif
