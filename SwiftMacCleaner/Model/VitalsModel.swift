//
//  VitalsModel.swift
//  SwiftMacCleaner
//

import Observation
import SwiftUI

/// The Mac's readings for the menu bar: what the tiles show, whose details are open, and when the
/// Mac is asked again.
///
/// It reads only while someone can see the answer: every two seconds while the menu is open, every
/// five while a reading stands beside the icon, and otherwise not at all.
@Observable
final class VitalsModel {
    /// How often the readings are taken, and how much of them.
    enum Pace {
        /// The menu is open: everything.
        case menu
        /// Only a reading beside the icon is on show: the processor and memory.
        case icon

        var interval: Duration { self == .menu ? .seconds(2) : .seconds(5) }
    }

    /// How soon the second look follows the first, which has nothing to measure the processor against.
    static let firstInterval: Duration = .milliseconds(500)
    /// A battery does not come and go, so the Mac is asked once.
    private static let hasBattery = BatteryReading.current() != nil

    let settings: AppSettings
    private(set) var readings = Vitals()
    /// The reading whose details are open beside the popover.
    private(set) var detail: VitalKind?
    private(set) var isMenuOpen = false
    /// Readings that stand in for the Mac's own, for the demo screens and for tests. While they are
    /// set the Mac is not asked anything, and quitting an app only takes it off the lists.
    @ObservationIgnored var standIn: Vitals? {
        didSet {
            if let standIn { readings = standIn }
            reschedule()
        }
    }

    @ObservationIgnored private let sampler = VitalsSampler()
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var pace: Pace?

    init(settings: AppSettings) {
        self.settings = settings
    }

    /// The tiles on the popover. A Mac without a battery has two.
    var kinds: [VitalKind] {
        let hasBattery = standIn.map { $0.battery != nil } ?? Self.hasBattery
        return hasBattery ? VitalKind.allCases : [.cpu, .memory]
    }

    /// What stands beside the icon in the menu bar. Nil when nothing was asked for, or nothing has
    /// been read yet.
    var iconReadings: String? {
        var parts: [String] = []
        if settings.showsCPUBesideIcon, let cpu = readings.cpu {
            parts.append("CPU \(VitalFormat.percent(cpu.load))")
        }
        if settings.showsMemoryBesideIcon, let memory = readings.memory {
            parts.append("RAM \(VitalFormat.percent(memory.pressure))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "  ")
    }

    // MARK: When to read

    /// Starts following the settings, so a reading asked for beside the icon appears without the
    /// menu ever being opened.
    func start() {
        reschedule()
        withObservationTracking {
            _ = settings.showsMenuBarItem
            _ = settings.showsCPUBesideIcon
            _ = settings.showsMemoryBesideIcon
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.start() }
        }
    }

    func menuOpened() {
        isMenuOpen = true
        reschedule()
    }

    func menuClosed() {
        isMenuOpen = false
        detail = nil
        reschedule()
        // Nobody is measuring any more, so the next opening starts clean instead of showing an old figure.
        if pace == nil, standIn == nil {
            readings.cpu = nil
            readings.byCPU = []
        }
    }

    /// The pace the readings are wanted at right now, or nil when nobody can see them.
    var wantedPace: Pace? {
        if standIn != nil { return nil }
        if isMenuOpen { return .menu }
        let showsReading = settings.showsCPUBesideIcon || settings.showsMemoryBesideIcon
        return settings.showsMenuBarItem && showsReading ? .icon : nil
    }

    private func reschedule() {
        let wanted = wantedPace
        guard wanted != pace else { return }
        pace = wanted
        loop?.cancel()
        loop = nil
        guard let wanted else { return }
        loop = Task { [weak self, sampler] in
            var isFirst = true
            while !Task.isCancelled {
                let latest = await sampler.sample(isFull: wanted == .menu)
                guard !Task.isCancelled, let self else { return }
                show(latest)
                try? await Task.sleep(for: isFirst && latest.cpu == nil ? Self.firstInterval : wanted.interval)
                isFirst = false
            }
        }
    }

    /// Puts new readings on show at once, with nothing easing into place. A ring that glides to each
    /// new figure has the whole popover redrawn for half a second out of every two, which costs more
    /// of the processor than everything the readings are made from.
    private func show(_ latest: Vitals) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            readings = latest
        }
    }

    // MARK: Details

    /// Opens the details of a reading, or closes them when they are the ones open.
    func toggle(_ kind: VitalKind) {
        detail = detail == kind ? nil : kind
    }

    /// Asks an app to quit, the way its own Quit command would, so it can still ask about unsaved
    /// work. It is never forced. The lists follow once the app is gone.
    func quit(_ consumer: Consumer) {
        guard let bundleID = consumer.bundleID else { return }
        if var standIn {
            standIn.byCPU.removeAll { $0.id == consumer.id }
            standIn.byMemory.removeAll { $0.id == consumer.id }
            self.standIn = standIn
            return
        }
        // Two copies of an app can be open at once; only the one in the list is asked.
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        where app.bundleURL?.standardizedFileURL.path == consumer.id {
            app.terminate()
        }
    }
}
