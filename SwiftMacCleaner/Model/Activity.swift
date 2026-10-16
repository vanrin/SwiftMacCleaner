//
//  Activity.swift
//  SwiftMacCleaner
//

import Foundation

/// One thing the app did on this Mac: a clean, an uninstall, a batch of updates, a run of maintenance
/// tasks, login or background items taken out, copies removed. My Activity adds these up and its
/// History lists them. Each is written once, when the work ends, from what the work itself reported.
nonisolated struct ActivityRecord: Codable, Identifiable, Sendable, Equatable {
    /// The part of the app that did it. A run from the overview is one record, and each of its lines
    /// names the part it came from.
    enum Part: String, Codable, CaseIterable, Sendable {
        case overview, system, developer, largeFiles, apps, performance, duplicates
    }

    enum Kind: String, Codable, Sendable {
        case clean, uninstall, leftovers, updates, tasks, loginItems, backgroundItems, duplicates
    }

    /// One line of what a record did: a group of items, an app, a task, an update.
    struct Line: Codable, Sendable, Equatable {
        enum Fate: String, Codable, Sendable {
            case deleted, trashEmptied, deletedAsRoot, ran, trashed, removed, updated, waited, failed

            /// Whether the line's size left the disk, or went to the Trash on its way out.
            var removes: Bool {
                switch self {
                case .deleted, .trashEmptied, .deletedAsRoot, .ran, .trashed, .removed: true
                case .updated, .waited, .failed: false
                }
            }
        }

        var what: String
        var fate: Fate
        /// What the scan measured. Nothing for a task, whose gain is only ever a guess.
        var size: Int64 = 0
        /// A few more words: why it waited, which version an app went to.
        var note: String? = nil
        var part: Part
    }

    /// Something the record moved to the Trash, which Put Back can return while it is still there.
    struct Trashed: Codable, Sendable, Equatable {
        var item: TrashedItem
        var part: Part
        var isPutBack = false
    }

    var id = UUID()
    var date: Date
    var part: Part
    var kind: Kind
    /// What it did, in a few words: "Uninstalled OpenWorker", "Ran 2 maintenance tasks".
    var title: String
    var lines: [Line] = []
    var trashed: [Trashed] = []
    /// How many items went.
    var itemCount = 0
    var appsUninstalled = 0
    var updatesInstalled = 0
    var tasksRun = 0
    var startupItemsRemoved = 0
    var copiesRemoved = 0
    /// What the run's own log is called, in the app's folder under ~/Library/Logs.
    var logFile: String? = nil
    /// One more sentence, for something worth knowing that is counted nowhere.
    var note: String? = nil
}

nonisolated extension ActivityRecord {
    /// What it removed, in one part or in all, less what has been put back since.
    func removed(in part: Part? = nil) -> Int64 {
        let gone = lines.filter { $0.fate.removes && (part == nil || $0.part == part) }.reduce(Int64(0)) { $0 + $1.size }
        let back = trashed.filter { $0.isPutBack && (part == nil || $0.part == part) }.reduce(Int64(0)) { $0 + $1.item.size }
        return max(0, gone - back)
    }

    /// Whether it counts as a clean: a clean-up or Applications' leftovers removed something.
    var isClean: Bool {
        (kind == .clean || kind == .leftovers) && (itemCount > 0 || removed() > 0)
    }

    /// The parts its lines came from, in the order they first appear.
    var parts: [Part] {
        var seen: [Part] = []
        for line in lines where !seen.contains(line.part) { seen.append(line.part) }
        return seen
    }

    /// What it moved to the Trash that is still on offer to be put back, given what Put Back holds.
    func waitingInTrash(pending: Set<URL>) -> [TrashedItem] {
        trashed.filter { !$0.isPutBack && pending.contains($0.item.inTrash) }.map(\.item)
    }
}

// MARK: - From what the work reported

nonisolated extension ActivityRecord {
    /// The line or lines for one step of a clean: what went, and what stayed and why.
    static func lines(for step: StepOutcome, part: Part, size: Int64? = nil, removedFate: Line.Fate? = nil) -> [Line] {
        if let reason = step.skippedReason {
            return [Line(what: step.title, fate: .waited, size: step.leftSize, note: shortReason(reason), part: part)]
        }
        var lines: [Line] = []
        let cleaned = size ?? step.cleanedSize
        if !step.cleanedItemIDs.isEmpty || cleaned > 0 {
            lines.append(Line(what: step.title, fate: removedFate ?? fate(of: step), size: cleaned, part: part))
        }
        if let reason = step.skippedItems.values.sorted().first {
            lines.append(Line(what: step.title, fate: .waited, size: step.leftSize, note: shortReason(reason), part: part))
        } else if let failure = step.failures.first {
            lines.append(Line(what: step.title, fate: .failed, size: step.leftSize, note: failure, part: part))
        }
        return lines
    }

    /// What became of a step's items, in the record's own words.
    static func fate(of step: StepOutcome) -> Line.Fate {
        if let fate = step.fate {
            return switch fate {
            case .deleted: .deleted
            case .trashEmptied: .trashEmptied
            case .deletedAsRoot: .deletedAsRoot
            case .run: .ran
            case .trashed: .trashed
            }
        }
        return switch step.method {
        case .delete: .deleted
        case .trash: .trashed
        case .command, .adminCommand: .ran
        case .adminDelete: .deletedAsRoot
        }
    }

    /// A receipt's sentence without the path in front, which the line already names.
    static func shortReason(_ reason: String) -> String {
        guard reason.hasPrefix("/") || reason.hasPrefix("~"), let colon = reason.range(of: ": ") else { return reason }
        let rest = reason[colon.upperBound...]
        return rest.prefix(1).uppercased() + rest.dropFirst()
    }

    /// What a run moved to the Trash, each item filed under the part whose step moved it.
    static func trashed(in outcome: CleanOutcome, part: (StepOutcome) -> Part) -> [Trashed] {
        outcome.steps.flatMap { step in step.trashed.map { Trashed(item: $0, part: part(step)) } }
    }

    /// One clean-up's clean.
    static func clean(_ outcome: CleanOutcome, part: Part) -> ActivityRecord {
        let lines = outcome.steps.flatMap { lines(for: $0, part: part) }
        return ActivityRecord(
            date: outcome.started, part: part, kind: .clean, title: cleanTitle(lines),
            lines: lines, trashed: trashed(in: outcome) { _ in part }, itemCount: outcome.cleanedItemIDs.count,
            logFile: outcome.logURL?.lastPathComponent
        )
    }

    /// "Cleaned App caches, Xcode DerivedData and 3 more", from the lines that removed something.
    static func cleanTitle(_ lines: [Line]) -> String {
        var names: [String] = []
        for line in lines where line.fate.removes && !names.contains(line.what) { names.append(line.what) }
        guard !names.isEmpty else { return "Nothing could be cleaned" }
        if names.count <= 3 { return "Cleaned " + ListFormat.string(names) }
        return "Cleaned \(names.prefix(2).joined(separator: ", ")) and \(names.count - 2) more"
    }

    /// Several records as the one run of the overview they were: every line in order, the counts
    /// added up, and the time and log of the first. Nil when the run did nothing.
    static func overview(_ records: [ActivityRecord]) -> ActivityRecord? {
        guard let first = records.first else { return nil }
        var merged = ActivityRecord(date: first.date, part: .overview, kind: .clean, title: "")
        for record in records {
            merged.lines += record.lines
            merged.trashed += record.trashed
            merged.itemCount += record.itemCount
            merged.appsUninstalled += record.appsUninstalled
            merged.updatesInstalled += record.updatesInstalled
            merged.tasksRun += record.tasksRun
            merged.startupItemsRemoved += record.startupItemsRemoved
            merged.copiesRemoved += record.copiesRemoved
            merged.logFile = merged.logFile ?? record.logFile
            if let note = record.note { merged.note = merged.note.map { "\($0) \(note)" } ?? note }
        }
        let cleanedParts = records.filter { $0.kind == .clean && $0.removed() > 0 }.map(\.part)
        let tasks = merged.tasksRun
        let taskWords = "\(tasks) \(tasks == 1 ? "task" : "tasks")"
        switch (cleanedParts.count, tasks) {
        case (0, 0): merged.title = "Nothing could be cleaned"
        case (0, _): merged.title = "Ran \(taskWords)"
        case (1, 0): merged.title = "Cleaned \(cleanedParts[0].title)"
        case (1, _): merged.title = "Cleaned \(cleanedParts[0].title) and ran \(taskWords)"
        case (let count, 0): merged.title = "Cleaned \(count) parts"
        case (let count, _): merged.title = "Cleaned \(count) parts and ran \(taskWords)"
        }
        return merged
    }

    /// Maintenance tasks, as Performance ran them. `ran` is what Performance counted as done.
    static func tasks(_ outcome: CleanOutcome, ran: [MaintenanceTask]) -> ActivityRecord {
        var lines = ran.map { Line(what: $0.title, fate: .ran, part: .performance) }
        for step in outcome.steps {
            if let reason = step.skippedReason {
                lines.append(Line(what: step.title, fate: .waited, note: shortReason(reason), part: .performance))
            } else if let failure = step.failures.first {
                lines.append(Line(what: step.title, fate: .failed, note: failure, part: .performance))
            }
        }
        var record = ActivityRecord(
            date: outcome.started, part: .performance, kind: .tasks,
            title: ran.isEmpty ? "No maintenance task could run" : "Ran \(ran.count == 1 ? ran[0].title : "\(ran.count) maintenance tasks")",
            lines: lines, tasksRun: ran.count, logFile: outcome.logURL?.lastPathComponent
        )
        if ran.contains(.purgeableSpace), outcome.reclaimed > 0 {
            record.note = "macOS gave back \(ByteFormat.string(outcome.reclaimed)) of purgeable space, which is not counted as cleaned."
        }
        return record
    }

    /// Login items or background items taken out, as Performance removed them.
    static func startupItems(_ outcome: CleanOutcome, kind: Kind, removed: Int) -> ActivityRecord {
        let noun = kind == .loginItems ? "login" : "background"
        let lines = outcome.steps.flatMap { lines(for: $0, part: .performance, removedFate: .removed) }
        return ActivityRecord(
            date: outcome.started, part: .performance, kind: kind,
            title: removed == 0 ? "No \(noun) item could be removed" : "Removed \(removed) \(noun) \(removed == 1 ? "item" : "items")",
            lines: lines, trashed: trashed(in: outcome) { _ in .performance }, itemCount: removed,
            startupItemsRemoved: removed, logFile: outcome.logURL?.lastPathComponent
        )
    }

    /// Apps uninstalled, or their files removed, from Applications. `sizes` is what each app's step
    /// removed, as Applications measures it, and `uninstalled` the names of the apps that went whole.
    static func uninstall(_ outcome: CleanOutcome, sizes: [String: Int64], uninstalled: [String], items: Int) -> ActivityRecord {
        let lines = outcome.steps.flatMap { lines(for: $0, part: .apps, size: sizes[$0.id]) }
        let title = switch uninstalled.count {
        case 0: lines.contains { $0.fate.removes } ? "Removed the files of \(ListFormat.string(lines.filter { $0.fate.removes }.map(\.what)))" : "No app could be uninstalled"
        case 1, 2: "Uninstalled \(ListFormat.string(uninstalled))"
        default: "Uninstalled \(uninstalled.count) apps"
        }
        return ActivityRecord(
            date: outcome.started, part: .apps, kind: .uninstall, title: title,
            lines: lines, trashed: trashed(in: outcome) { _ in .apps }, itemCount: items,
            appsUninstalled: uninstalled.count, logFile: outcome.logURL?.lastPathComponent
        )
    }

    /// What apps left behind, and installers, as Applications removed them.
    static func leftovers(_ outcome: CleanOutcome) -> ActivityRecord {
        let lines = outcome.steps.flatMap { lines(for: $0, part: .apps) }
        let count = outcome.cleanedItemIDs.count
        return ActivityRecord(
            date: outcome.started, part: .apps, kind: .leftovers,
            title: count == 0 ? "No leftover could be removed" : "Removed \(count) \(count == 1 ? "leftover" : "leftovers")",
            lines: lines, trashed: trashed(in: outcome) { _ in .apps }, itemCount: count,
            logFile: outcome.logURL?.lastPathComponent
        )
    }

    /// Copies of identical files moved to the Trash. `freed` is what Duplicates says the disk gets
    /// back, which leaves out copies that shared their space with the one kept.
    static func duplicates(_ outcome: CleanOutcome, copies: Int, freed: Int64) -> ActivityRecord {
        var lines: [Line] = []
        if copies > 0 {
            lines.append(Line(what: "\(copies) \(copies == 1 ? "copy" : "copies")", fate: .trashed, size: freed, part: .duplicates))
        }
        for step in outcome.steps {
            if let reason = step.skippedItems.values.sorted().first ?? step.skippedReason {
                lines.append(Line(what: step.title, fate: .waited, note: shortReason(reason), part: .duplicates))
            } else if let failure = step.failures.first {
                lines.append(Line(what: step.title, fate: .failed, note: failure, part: .duplicates))
            }
        }
        return ActivityRecord(
            date: outcome.started, part: .duplicates, kind: .duplicates,
            title: copies == 0 ? "No copy could be removed" : "Removed \(copies) \(copies == 1 ? "copy" : "copies")",
            lines: lines, trashed: trashed(in: outcome) { _ in .duplicates }, itemCount: copies,
            copiesRemoved: copies, logFile: outcome.logURL?.lastPathComponent
        )
    }

    /// Updates Homebrew installed: each app, and the version it went from and to.
    static func updates(_ installed: [(name: String, from: String, to: String)], date: Date) -> ActivityRecord {
        let lines = installed.map { Line(what: $0.name, fate: .updated, note: "\($0.from) → \($0.to)", part: .apps) }
        let title = installed.count == 1 ? "Updated \(installed[0].name)" : "Installed \(installed.count) updates"
        return ActivityRecord(date: date, part: .apps, kind: .updates, title: title + " with Homebrew",
                              lines: lines, itemCount: installed.count, updatesInstalled: installed.count)
    }
}

nonisolated extension ActivityRecord.Part {
    var title: String {
        switch self {
        case .overview: "Overview"
        case .system: AreaGroup.system.title
        case .developer: AreaGroup.developer.title
        case .largeFiles: AreaGroup.largeFiles.title
        case .apps: "Applications"
        case .performance: "Performance"
        case .duplicates: "Duplicates"
        }
    }

    init(_ group: AreaGroup) {
        self = switch group {
        case .system: .system
        case .developer: .developer
        case .largeFiles: .largeFiles
        }
    }
}

// MARK: - Protection

/// How the Protection check last found this Mac, kept so My Activity can say so after the app is
/// opened again. Only what was shown is kept: the name of each setting and how it stood.
nonisolated struct ProtectionSnapshot: Codable, Sendable, Equatable {
    struct Setting: Codable, Sendable, Equatable {
        enum State: String, Codable, Sendable {
            case inPlace, needsLook, accepted, unknown
        }

        var name: String
        var status: String
        var state: State
    }

    var date: Date
    var settings: [Setting]

    var inPlace: Int { settings.count { $0.state == .inPlace } }
    var toCheck: [Setting] { settings.filter { $0.state == .needsLook } }
}

// MARK: - On disk

/// Where the record of everything the app did is kept: one file beside the Put Back manifest, written
/// whole each time something is added. Nothing in it leaves this Mac.
nonisolated enum ActivityLog {
    static let fileName = "activity.json"
    /// The oldest records go once there are more than this many, which is years of daily use.
    static let limit = 5_000

    struct Stored: Codable, Sendable, Equatable {
        /// Oldest first.
        var records: [ActivityRecord] = []
        var protection: ProtectionSnapshot? = nil
    }

    static func url(home: URL) -> URL {
        home.appending(path: "Library/Application Support").appending(path: CleanLog.folderName).appending(path: fileName)
    }

    static func load(home: URL) -> Stored {
        guard let data = try? Data(contentsOf: url(home: home)) else { return Stored() }
        return (try? JSONDecoder().decode(Stored.self, from: data)) ?? Stored()
    }

    static func save(_ stored: Stored, home: URL) {
        var stored = stored
        if stored.records.count > limit { stored.records.removeFirst(stored.records.count - limit) }
        let url = url(home: home)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(stored).write(to: url, options: .atomic)
    }

    /// Adds one record, for work done without the window.
    static func append(_ record: ActivityRecord, home: URL) {
        var stored = load(home: home)
        stored.records.append(record)
        save(stored, home: home)
    }
}

// MARK: - In words

nonisolated extension ActivityRecord {
    /// The figure at the end of its row: what it cleaned, or else how many things it did.
    var figure: String {
        let removed = removed()
        if removed > 0 { return ByteFormat.string(removed) }
        if updatesInstalled > 0 { return Self.count(updatesInstalled, "update") }
        if tasksRun > 0 { return Self.count(tasksRun, "task") }
        if startupItemsRemoved > 0 { return Self.count(startupItemsRemoved, "item") }
        if appsUninstalled > 0 { return Self.count(appsUninstalled, "app") }
        return "Nothing"
    }

    /// The line under its title.
    var detail: String {
        let done = lines.filter { $0.fate != .waited && $0.fate != .failed }.map(\.what)
        return switch kind {
        case .clean where part == .overview: ListFormat.string(parts.filter { $0 != .overview }.map(\.title))
        case .clean, .leftovers: Self.count(itemCount, "item")
        case .uninstall: "\(Self.count(itemCount, "item")) moved to the Trash"
        case .updates, .tasks, .loginItems, .backgroundItems: ListFormat.string(done)
        case .duplicates: "One copy of each file kept"
        }
    }

    /// "1 task", "3 tasks".
    static func count(_ count: Int, _ noun: String) -> String {
        "\(count.formatted()) \(count == 1 ? noun : noun + "s")"
    }
}

nonisolated extension ActivityRecord.Line {
    /// What became of it, as History says it.
    var fateText: String {
        switch fate {
        case .deleted: "Deleted"
        case .trashEmptied: "Emptied from the Trash"
        case .deletedAsRoot: "Deleted with your password"
        case .ran: "Run"
        case .trashed: "Moved to the Trash"
        case .removed: "Removed"
        case .updated: note ?? "Updated"
        case .waited: "Left alone" + (note.map { ": \($0)" } ?? "")
        case .failed: "Not removed" + (note.map { ": \($0)" } ?? "")
        }
    }
}
