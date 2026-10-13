//
//  VitalsSampler.swift
//  SwiftMacCleaner
//

import Foundation

/// Takes the readings off the main thread, and remembers the counts each look is measured against:
/// processor time only means something as the difference between two looks.
actor VitalsSampler {
    /// Counts older than this are not measured against. The difference would be an average over
    /// however long nobody looked, not what the Mac is doing now.
    static let staleAfter: Duration = .seconds(15)

    private let clock = ContinuousClock()
    private var ticks: [CPUTicks] = []
    private var ticksAt: ContinuousClock.Instant?
    private var processes: [pid_t: ProcessUsage] = [:]
    private var processesAt: ContinuousClock.Instant?
    /// What each program outside an app calls itself, kept so its bundle is read once.
    private var names: [String: String?] = [:]

    /// The readings right now. The processor's part is missing from the first look after a pause,
    /// which only sets down what the next one is measured against.
    /// - Parameter isFull: Off for the reading beside the icon, which needs neither the battery nor
    ///   what each app uses.
    func sample(isFull: Bool) -> Vitals {
        var vitals = Vitals(memory: MemoryReading.current())
        let now = clock.now
        let latest = CPUTicks.current()
        if let ticksAt, now - ticksAt <= Self.staleAfter {
            vitals.cpu = CPUReading.current(from: ticks, to: latest)
        }
        ticks = latest
        ticksAt = now
        guard isFull else { return vitals }

        vitals.battery = BatteryReading.current()
        let usages = ProcessUsage.all(knownPaths: processes)
        var elapsed: TimeInterval = 0
        if let processesAt, now - processesAt <= Self.staleAfter {
            let passed = (now - processesAt).components
            elapsed = Double(passed.seconds) + Double(passed.attoseconds) / 1e18
        }
        let consumers = Consumer.grouped(usages, since: elapsed > 0 ? processes : [:], elapsed: elapsed,
                                         apps: RunningApp.all(), own: Bundle.main.bundleIdentifier, name: name(ofProgramAt:))
        vitals.byCPU = consumers.top(by: .cpu)
        vitals.byMemory = consumers.top(by: .memory)
        processes = Dictionary(usages.map { ($0.pid, $0) }) { _, last in last }
        processesAt = now
        return vitals
    }

    private func name(ofProgramAt path: String) -> String? {
        if let known = names[path] { return known }
        let name = Consumer.bundleName(ofProgramAt: path)
        names[path] = name
        return name
    }
}
