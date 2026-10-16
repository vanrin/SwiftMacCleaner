//
//  ActivityModel.swift
//  SwiftMacCleaner
//

import AppKit
import Observation

/// State behind My Activity: the record of what the app has done on this Mac, the figures it adds up
/// to, and which page of it is on screen. Every figure is counted from the record; none is estimated.
@Observable
final class ActivityModel {
    /// What History shows.
    enum Filter: String, CaseIterable, Identifiable {
        case all, cleanUps, apps, performance, duplicates

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: "All"
            case .cleanUps: "Clean-ups"
            case .apps: "Applications"
            case .performance: "Performance"
            case .duplicates: "Duplicates"
            }
        }

        func shows(_ record: ActivityRecord) -> Bool {
            switch self {
            case .all: true
            case .cleanUps: [.overview, .system, .developer, .largeFiles].contains(record.part)
            case .apps: record.part == .apps
            case .performance: record.part == .performance
            case .duplicates: record.part == .duplicates
            }
        }
    }

    /// One month of History, newest first.
    struct Month: Identifiable {
        var start: Date
        var records: [ActivityRecord]

        var id: Date { start }
        var cleaned: Int64 { records.reduce(0) { $0 + $1.removed() } }
    }

    /// One kind of thing done besides cleaning, and how often.
    struct Tally: Identifiable, Equatable {
        var name: String
        var count: Int

        var id: String { name }
    }

    /// The parts whose cleaning adds up to the total, in the order the sidebar lists them.
    static let cleaningParts: [ActivityRecord.Part] = [.system, .developer, .largeFiles, .apps, .duplicates]

    let home: URL
    /// Off for the made-up screens, whose work must not count as real.
    @ObservationIgnored var isRecording = true
    /// Everything the app has done, oldest first.
    private(set) var records: [ActivityRecord]
    /// How the Protection check last found this Mac.
    private(set) var protection: ProtectionSnapshot?

    /// Whether the full list is on screen, in place of the cards.
    var showsHistory = false
    var filter = Filter.all
    /// The record of History whose lines are open.
    var expanded: ActivityRecord.ID?

    /// The records of an overview run while it is under way. They are kept as one when it ends.
    @ObservationIgnored private var runRecords: [ActivityRecord]?

    init(home: URL) {
        self.home = home
        let stored = ActivityLog.load(home: home)
        records = stored.records
        protection = stored.protection
    }

    // MARK: Recording

    func add(_ record: ActivityRecord) {
        guard isRecording else { return }
        if runRecords != nil {
            runRecords?.append(record)
            return
        }
        records.append(record)
        save()
    }

    /// From here until `finishRun()`, what the parts do is one run of the overview.
    func beginRun() {
        runRecords = []
    }

    func finishRun() {
        guard let collected = runRecords else { return }
        runRecords = nil
        guard isRecording, let merged = ActivityRecord.overview(collected) else { return }
        records.append(merged)
        save()
    }

    /// Notes that these items are back where they were, which takes them off what was cleaned.
    func markPutBack(_ items: [TrashedItem]) {
        let back = Set(items.map(\.inTrash))
        guard isRecording, !back.isEmpty else { return }
        var changed = false
        for index in records.indices {
            for item in records[index].trashed.indices where !records[index].trashed[item].isPutBack
                && back.contains(records[index].trashed[item].item.inTrash) {
                records[index].trashed[item].isPutBack = true
                changed = true
            }
        }
        if changed { save() }
    }

    /// Keeps how the Protection check found this Mac.
    func keep(_ snapshot: ProtectionSnapshot) {
        guard isRecording else { return }
        protection = snapshot
        save()
    }

    private func save() {
        ActivityLog.save(ActivityLog.Stored(records: records, protection: protection), home: home)
    }

    // MARK: Figures

    /// When the record starts.
    var since: Date? { records.first?.date }
    var isEmpty: Bool { records.isEmpty }

    /// Everything cleaned, less what was put back.
    var cleaned: Int64 { records.reduce(0) { $0 + $1.removed() } }

    /// What was cleaned in each part that cleans, the largest first, leaving out parts with nothing.
    var cleanedByPart: [(part: ActivityRecord.Part, size: Int64)] {
        Self.cleaningParts
            .map { part in (part, records.reduce(Int64(0)) { $0 + $1.removed(in: part) }) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
    }

    /// The records from the start of this month on.
    func thisMonth(now: Date = Date(), calendar: Calendar = .current) -> [ActivityRecord] {
        guard let start = calendar.dateInterval(of: .month, for: now)?.start else { return [] }
        return records.filter { $0.date >= start }
    }

    func cleanedThisMonth(now: Date = Date()) -> Int64 { thisMonth(now: now).reduce(0) { $0 + $1.removed() } }

    var cleans: Int { records.count(where: \.isClean) }
    func cleansThisMonth(now: Date = Date()) -> Int { thisMonth(now: now).count(where: \.isClean) }

    /// Cleans in each of the last `weeks` weeks, the oldest first and this week last.
    func weeklyCleans(weeks: Int = 10, now: Date = Date(), calendar: Calendar = .current) -> [Int] {
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        return (0..<weeks).reversed().map { back in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -back, to: thisWeek),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { return 0 }
            return records.count { $0.isClean && $0.date >= start && $0.date < end }
        }
    }

    /// What was done besides cleaning, every kind listed even when it has not happened yet.
    var tallies: [Tally] {
        [
            Tally(name: "Apps uninstalled", count: records.reduce(0) { $0 + $1.appsUninstalled }),
            Tally(name: "Updates installed", count: records.reduce(0) { $0 + $1.updatesInstalled }),
            Tally(name: "Maintenance tasks run", count: records.reduce(0) { $0 + $1.tasksRun }),
            Tally(name: "Login and background items removed", count: records.reduce(0) { $0 + $1.startupItemsRemoved }),
            Tally(name: "Duplicate copies removed", count: records.reduce(0) { $0 + $1.copiesRemoved }),
        ]
    }

    /// The newest records, newest first.
    func recent(_ count: Int) -> [ActivityRecord] { Array(records.suffix(count).reversed()) }

    /// When a part last cleaned something, from any record that has a line of it.
    func lastClean(of part: ActivityRecord.Part) -> Date? {
        records.last { record in record.lines.contains { $0.part == part && $0.fate.removes && $0.size > 0 } }?.date
    }

    /// History under the filter, a month at a time, newest first.
    func months(calendar: Calendar = .current) -> [Month] {
        var months: [Month] = []
        for record in records.reversed() where filter.shows(record) {
            let start = calendar.dateInterval(of: .month, for: record.date)?.start ?? record.date
            if months.last?.start == start {
                months[months.count - 1].records.append(record)
            } else {
                months.append(Month(start: start, records: [record]))
            }
        }
        return months
    }

    // MARK: Pages

    func showHistory() {
        expanded = records.last?.id
        showsHistory = true
    }

    func showCards() {
        showsHistory = false
    }

    func toggle(_ record: ActivityRecord) {
        expanded = expanded == record.id ? nil : record.id
    }

    /// The run's own log, while it is still there.
    func logURL(of record: ActivityRecord) -> URL? {
        guard let name = record.logFile else { return nil }
        let url = home.appending(path: "Library/Logs").appending(path: CleanLog.folderName).appending(path: name)
        return Files.exists(url) ? url : nil
    }

    func open(_ log: URL) {
        NSWorkspace.shared.open(log)
    }

    // MARK: Demo

    /// Fills the record with made-up work for the screens that show it, without touching the file.
    func showDemo(records: [ActivityRecord], protection: ProtectionSnapshot?) {
        isRecording = false
        self.records = records
        self.protection = protection
    }
}
