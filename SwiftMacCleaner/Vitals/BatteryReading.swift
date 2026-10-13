//
//  BatteryReading.swift
//  SwiftMacCleaner
//

import Foundation
import IOKit
import IOKit.ps

/// What the Mac's battery is doing and what shape it is in. A Mac without one has no reading.
nonisolated struct BatteryReading: Equatable, Sendable {
    enum State: Sendable {
        case charged, charging, onBattery
        /// Plugged in and holding where it is, as macOS does to spare the battery.
        case notCharging
    }

    /// At or below this, away from the adapter, the battery counts as low.
    static let lowCharge = 0.2

    /// From 0 to 1.
    var charge: Double
    var state: State
    /// Minutes until empty, or until full, once macOS has worked it out.
    var minutesLeft: Int?
    var minutesToFull: Int?
    /// What the connected adapter can deliver, in watts.
    var adapterWatts: Int?
    var cycles: Int?
    /// How many cycles the battery was built to last.
    var designCycles: Int?
    /// What the battery holds when full today and what it held when new, in milliamp hours.
    var capacity: Int?
    var designCapacity: Int?

    /// The share of its first capacity the battery still holds, from 0 to 1.
    var health: Double? {
        guard let capacity, let designCapacity, designCapacity > 0 else { return nil }
        return min(1, Double(capacity) / Double(designCapacity))
    }

    var isLow: Bool { state == .onBattery && charge <= Self.lowCharge }
    var level: VitalLevel { isLow ? .high : .normal }

    var title: String {
        switch state {
        case .charged: "Fully charged"
        case .charging: "Charging"
        case .onBattery: "On battery"
        case .notCharging: "Not charging"
        }
    }

    var detail: String {
        switch state {
        case .charged: "Running on the power adapter."
        case .charging: minutesToFull.map { "\(VitalFormat.clock(minutes: $0)) until full." } ?? "Working out how long it will take."
        case .onBattery: minutesLeft.map { "About \(VitalFormat.clock(minutes: $0)) left." } ?? "Working out how long is left."
        case .notCharging: "Plugged in, and holding at this level."
        }
    }

    /// The line on the Battery tile.
    var line: String {
        switch state {
        case .charged: title
        case .charging: minutesToFull.map { "\(VitalFormat.clock(minutes: $0)) to full" } ?? title
        case .onBattery: minutesLeft.map { "\(VitalFormat.clock(minutes: $0)) left" } ?? title
        case .notCharging: title
        }
    }

    var summary: VitalSummary { VitalSummary(fraction: charge, line: line, level: level) }

    var facts: [VitalFact] {
        var facts: [VitalFact] = []
        if let health {
            // Rounded down, as System Information states it.
            facts.append(VitalFact(title: "Health", value: VitalFormat.percent((health * 100).rounded(.down) / 100), detail: "Of the charge it held when new."))
        }
        if let cycles {
            let design = designCycles.map { "Built for \(VitalFormat.count($0))." } ?? "Full charges so far."
            facts.append(VitalFact(title: "Cycles", value: VitalFormat.count(cycles), detail: design))
        }
        if let capacity, let designCapacity {
            facts.append(VitalFact(title: "Holds", value: "\(VitalFormat.count(capacity)) mAh",
                                   detail: "\(VitalFormat.count(designCapacity)) mAh when new."))
        }
        if state == .onBattery {
            facts.append(VitalFact(title: "Adapter", value: "None", detail: "Running on the battery alone."))
        } else {
            facts.append(VitalFact(title: "Adapter", value: adapterWatts.map { "\($0) W" } ?? "Connected", detail: "What it can deliver at most."))
        }
        return facts
    }

    init(charge: Double, state: State, minutesLeft: Int? = nil, minutesToFull: Int? = nil, adapterWatts: Int? = nil,
         cycles: Int? = nil, designCycles: Int? = nil, capacity: Int? = nil, designCapacity: Int? = nil) {
        self.charge = charge
        self.state = state
        self.minutesLeft = minutesLeft
        self.minutesToFull = minutesToFull
        self.adapterWatts = adapterWatts
        self.cycles = cycles
        self.designCycles = designCycles
        self.capacity = capacity
        self.designCapacity = designCapacity
    }

    /// - Parameters:
    ///   - source: macOS's description of the power source. Nil when it is not the built-in battery.
    ///   - adapter: What macOS says about the connected adapter.
    ///   - registry: The battery's own entry, which holds what the description leaves out: its
    ///     cycles and what it holds.
    init?(source: [String: Any], adapter: [String: Any]?, registry: [String: Any]) {
        guard source[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
              let current = source[kIOPSCurrentCapacityKey] as? Int,
              let full = source[kIOPSMaxCapacityKey] as? Int, full > 0 else { return nil }
        let charge = min(1, max(0, Double(current) / Double(full)))
        let isPlugged = source[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
        let state: State = if !isPlugged {
            .onBattery
        } else if source[kIOPSIsChargingKey] as? Bool == true {
            .charging
        } else if source[kIOPSIsChargedKey] as? Bool == true || charge >= 1 {
            .charged
        } else {
            .notCharging
        }
        /// macOS answers -1, and sometimes 0, while it is still working an estimate out.
        func minutes(_ key: String) -> Int? {
            (source[key] as? Int).flatMap { $0 > 0 ? $0 : nil }
        }
        // Newer systems keep the capacities one level down.
        let data = registry["BatteryData"] as? [String: Any] ?? [:]
        func number(_ key: String) -> Int? {
            ((data[key] ?? registry[key]) as? Int).flatMap { $0 > 0 ? $0 : nil }
        }
        self.init(
            charge: charge,
            state: state,
            minutesLeft: state == .onBattery ? minutes(kIOPSTimeToEmptyKey) : nil,
            minutesToFull: state == .charging ? minutes(kIOPSTimeToFullChargeKey) : nil,
            adapterWatts: isPlugged ? (adapter?[kIOPSPowerAdapterWattsKey] as? Int).flatMap { $0 > 0 ? $0 : nil } : nil,
            cycles: registry["CycleCount"] as? Int,
            designCycles: number("DesignCycleCount9C"),
            capacity: number("NominalChargeCapacity") ?? number("AppleRawMaxCapacity"),
            designCapacity: number("DesignCapacity")
        )
    }

    /// The built-in battery right now, or nil on a Mac that has none.
    static func current() -> BatteryReading? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        let adapter = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any]
        let registry = registryEntry()
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  let reading = BatteryReading(source: description, adapter: adapter, registry: registry) else { continue }
            return reading
        }
        return nil
    }

    private static func registryEntry() -> [String: Any] {
        let battery = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard battery != 0 else { return [:] }
        defer { IOObjectRelease(battery) }
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(battery, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS else { return [:] }
        return properties?.takeRetainedValue() as? [String: Any] ?? [:]
    }
}
