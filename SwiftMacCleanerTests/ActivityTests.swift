//
//  ActivityTests.swift
//  SwiftMacCleanerTests
//
//  The record of what the app did, and the figures My Activity adds up from it.
//

import Foundation
import Testing
@testable import SwiftMacCleaner

private struct Sandbox {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "mdc-activity-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    @discardableResult
    func file(_ path: String, bytes: Int = 16) throws -> URL {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 7, count: bytes).write(to: url)
        return url
    }
}

private func finding(_ id: String, area: Area = .cachesLogs, method: CleanMethod = .delete, items: [FindingItem]) -> Finding {
    Finding(id: id, area: area, aftermath: method == .trash ? .downloadsAgain : .rebuilds, title: id, summary: "",
            explanation: "", method: method, actionTarget: "", items: items)
}

private func step(_ id: String, size: Int64, fate: CleanFate = .deleted, items: [String] = ["x"], trashed: [TrashedItem] = []) -> StepOutcome {
    var step = StepOutcome(id: id, title: id, method: fate == .trashed ? .trash : .delete, size: size, cleanedItemIDs: items,
                           failures: [], trashed: trashed, fate: fate)
    step.cleanedSize = size
    return step
}

private func outcome(_ steps: [StepOutcome], started: Date = Date()) -> CleanOutcome {
    CleanOutcome(steps: steps, freeBefore: 0, freeAfter: 0, trashedSize: steps.flatMap(\.trashed).reduce(0) { $0 + $1.size },
                 duration: 0, logURL: nil, started: started)
}

struct ActivityRecordTests {
    /// A step says how much of it went and how much stayed, from the sizes the scan measured.
    @Test func aCleanMeasuresWhatWentAndWhatWaited() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let gone = try sandbox.file("Library/Caches/one/data", bytes: 10)
        let kept = try sandbox.file("Library/Caches/two/data", bytes: 10)
        let items = [
            FindingItem(id: "c/one", title: "one", detail: "", size: 600, paths: [gone.deletingLastPathComponent()]),
            FindingItem(id: "c/two", title: "two", detail: "", size: 400, paths: [kept.deletingLastPathComponent()]),
        ]
        let plan = CleanPlan.make(findings: [finding("caches", items: items)], selection: ["c/one", "c/two"])
        let result = await Cleaner.run(plan: plan, safety: SafetyGuard(root: sandbox.root),
                                       waiting: ["c/two": "two: Safari is still open, so it was left alone"]) { _ in }
        let measured = try #require(result.steps.first)
        #expect(measured.cleanedSize == 600)
        #expect(measured.leftSize == 400)

        let record = ActivityRecord.clean(result, part: .system)
        #expect(record.removed() == 600)
        #expect(record.removed(in: .system) == 600)
        #expect(record.removed(in: .developer) == 0)
        #expect(record.lines.map(\.fate) == [.deleted, .waited])
        #expect(record.lines.last?.size == 400)
        #expect(record.itemCount == 1)
        #expect(record.title == "Cleaned caches")
        #expect(record.isClean)
    }

    /// A step that waited whole removes nothing and says why, without the path in front.
    @Test func aStepLeftAloneSaysWhy() {
        var waited = StepOutcome(id: "xcode", title: "Xcode", method: .delete, size: 900, cleanedItemIDs: [], failures: [],
                                 skippedReason: "/Users/me/Library/Developer: Xcode is open, so it was left alone")
        waited.leftSize = 900
        let record = ActivityRecord.clean(outcome([waited]), part: .developer)
        #expect(record.lines == [ActivityRecord.Line(what: "Xcode", fate: .waited, size: 900,
                                                     note: "Xcode is open, so it was left alone", part: .developer)])
        #expect(record.removed() == 0)
        #expect(record.title == "Nothing could be cleaned")
        #expect(!record.isClean)
    }

    /// A run of the overview is one record, whichever parts it went through, and each line keeps its part.
    @Test func anOverviewRunIsOneRecord() throws {
        let system = ActivityRecord.clean(outcome([step("App caches", size: 300)]), part: .system)
        let developer = ActivityRecord.clean(outcome([step("DerivedData", size: 700)]), part: .developer)
        let tasks = ActivityRecord.tasks(outcome([]), ran: [.flushDNS, .speedUpMail])
        let merged = try #require(ActivityRecord.overview([system, developer, tasks]))
        #expect(merged.part == .overview)
        #expect(merged.title == "Cleaned 2 parts and ran 2 tasks")
        #expect(merged.removed() == 1000)
        #expect(merged.removed(in: .developer) == 700)
        #expect(merged.tasksRun == 2)
        #expect(merged.parts == [.system, .developer, .performance])
        #expect(merged.detail == "System Clean Up, Developer Clean Up and Performance")
        #expect(merged.isClean)
        #expect(ActivityRecord.overview([]) == nil)
    }

    /// Duplicates counts what the disk gets back, which leaves out copies that shared their space.
    @Test func duplicatesCountWhatTheDiskGetsBack() {
        let record = ActivityRecord.duplicates(outcome([step("group", size: 5_000, fate: .trashed)]), copies: 3, freed: 2_000)
        #expect(record.removed() == 2_000)
        #expect(record.copiesRemoved == 3)
        #expect(record.title == "Removed 3 copies")
        #expect(!record.isClean)
    }

    @Test func updatesSayWhichVersionEachAppWentTo() {
        let record = ActivityRecord.updates([("Relay", "2.4.1", "2.5.0")], date: Date())
        #expect(record.title == "Updated Relay with Homebrew")
        #expect(record.lines.first?.fateText == "2.4.1 → 2.5.0")
        #expect(record.updatesInstalled == 1)
        #expect(record.figure == "1 update")
    }
}

@MainActor
struct ActivityModelTests {
    /// Dates in the middle of a week and of a month, so the tests do not depend on today.
    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12))!

    private func clean(_ part: ActivityRecord.Part, _ size: Int64, daysAgo: Double) -> ActivityRecord {
        ActivityRecord.clean(outcome([step("\(part)", size: size)], started: now.addingTimeInterval(-daysAgo * 86_400)), part: part)
    }

    @Test func theRecordIsKeptOnDiskAndReadBack() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let activity = ActivityModel(home: sandbox.root)
        activity.add(clean(.system, 100, daysAgo: 1))
        activity.keep(ProtectionSnapshot(date: now, settings: [.init(name: "Firewall", status: "Off", state: .needsLook)]))

        let again = ActivityModel(home: sandbox.root)
        #expect(again.records == activity.records)
        #expect(again.protection?.toCheck.map(\.name) == ["Firewall"])
        #expect(Files.exists(ActivityLog.url(home: sandbox.root)))
    }

    /// The made-up screens never write to the record.
    @Test func aDemoKeepsNothing() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let activity = ActivityModel(home: sandbox.root)
        activity.showDemo(records: [], protection: nil)
        activity.add(clean(.system, 100, daysAgo: 1))
        #expect(activity.records.isEmpty)
        #expect(!Files.exists(ActivityLog.url(home: sandbox.root)))
    }

    @Test func theFiguresAddUpFromTheRecord() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let activity = ActivityModel(home: sandbox.root)
        activity.add(clean(.developer, 700, daysAgo: 40))
        activity.add(clean(.system, 200, daysAgo: 8))
        activity.add(clean(.system, 100, daysAgo: 1))
        activity.add(ActivityRecord.uninstall(outcome([step("uninstall/a", size: 50, fate: .trashed)]), sizes: ["uninstall/a": 50],
                                              uninstalled: ["Alpha"], items: 2))

        #expect(activity.cleaned == 1_050)
        #expect(activity.cleanedByPart.map(\.part) == [.developer, .system, .apps])
        #expect(activity.cleanedByPart.map(\.size) == [700, 300, 50])
        // An uninstall is counted among what else was done, not among the cleans.
        #expect(activity.cleans == 3)
        #expect(activity.tallies.first == ActivityModel.Tally(name: "Apps uninstalled", count: 1))
        #expect(activity.cleansThisMonth(now: now) == 2)
        #expect(activity.weeklyCleans(weeks: 10, now: now).suffix(2) == [1, 1])
        #expect(activity.weeklyCleans(weeks: 10, now: now).reduce(0, +) == 3)
        #expect(activity.recent(2).map(\.part) == [.apps, .system])
        #expect(activity.months().count == 2)
    }

    /// Everything the parts do between the start and the end of a run is kept as one record.
    @Test func aRunCollectsWhatThePartsRecord() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let activity = ActivityModel(home: sandbox.root)
        activity.beginRun()
        activity.add(clean(.system, 100, daysAgo: 0))
        activity.add(clean(.developer, 200, daysAgo: 0))
        #expect(activity.records.isEmpty)
        activity.finishRun()
        #expect(activity.records.count == 1)
        #expect(activity.records.first?.part == .overview)
        #expect(activity.cleaned == 300)
    }

    /// What is put back no longer counts as cleaned, in the part it came from.
    @Test func putBackTakesItOffAgain() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let item = TrashedItem(original: sandbox.root.appending(path: "Downloads/a.dmg"), inTrash: sandbox.root.appending(path: ".Trash/a.dmg"), size: 400)
        let activity = ActivityModel(home: sandbox.root)
        activity.add(.clean(outcome([step("dmg", size: 400, fate: .trashed, trashed: [item]), step("caches", size: 100)]), part: .largeFiles))
        #expect(activity.cleaned == 500)
        #expect(activity.records[0].waitingInTrash(pending: [item.inTrash]) == [item])

        activity.markPutBack([item])
        #expect(activity.cleaned == 100)
        #expect(activity.records[0].waitingInTrash(pending: [item.inTrash]).isEmpty)
        #expect(ActivityModel(home: sandbox.root).cleaned == 100)
    }

    @Test func historyFiltersByPart() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let activity = ActivityModel(home: sandbox.root)
        activity.add(clean(.system, 100, daysAgo: 1))
        activity.add(ActivityRecord.tasks(outcome([]), ran: [.flushDNS]))
        activity.filter = .performance
        #expect(activity.months().flatMap(\.records).map(\.kind) == [.tasks])
        activity.filter = .cleanUps
        #expect(activity.months().flatMap(\.records).map(\.kind) == [.clean])
    }
}

@MainActor
struct ActivityAppTests {
    private func temporaryHome() throws -> URL {
        let home = FileManager.default.temporaryDirectory.appending(path: "mdc-activity-app-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        return home
    }

    /// A removal in a part reaches the record without the part knowing about My Activity.
    @Test func aPartsWorkReachesTheRecord() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let model = AppModel(home: home, settings: AppSettings(defaults: MemoryDefaults()))
        model.duplicates.showDemo("done")
        let record = try #require(model.activity.records.last)
        #expect(record.part == .duplicates)
        #expect(record.copiesRemoved == model.duplicates.removal.files)
    }

    @Test func myActivityHasAnEntryAndComesBackFromHistory() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let model = AppModel(home: home, settings: AppSettings(defaults: MemoryDefaults()))
        #expect(model.sidebarStatus(of: .activity) == SidebarStatus())
        #expect(!SidebarItem.parts.contains(.activity))
        model.select(.activity)
        model.activity.showHistory()
        model.select(.activity)
        #expect(!model.activity.showsHistory)
    }

    /// On a Mac nothing has been done on, the first thing worth doing is a scan.
    @Test func aFreshMacIsAskedForAFirstScan() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let model = AppModel(home: home, settings: AppSettings(defaults: MemoryDefaults()))
        #expect(model.suggestions().first?.id == "first-scan")
    }

    /// Putting back one run's items leaves another run's items on offer.
    @Test func oneRunCanBePutBackAlone() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let fileManager = FileManager.default
        var items: [TrashedItem] = []
        for name in ["a", "b"] {
            let inTrash = home.appending(path: ".Trash/\(name).dmg")
            try fileManager.createDirectory(at: inTrash.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(count: 5).write(to: inTrash)
            items.append(TrashedItem(original: home.appending(path: "Downloads/\(name).dmg"), inTrash: inTrash, size: 5))
        }
        let first = outcome([step("a", size: 5, fate: .trashed, trashed: [items[0]])])
        let second = outcome([step("b", size: 5, fate: .trashed, trashed: [items[1]])])
        PutBack.save(first, home: home)
        PutBack.save(second, home: home)
        let model = AppModel(home: home, settings: AppSettings(defaults: MemoryDefaults()))
        model.activity.add(.clean(first, part: .largeFiles))
        model.activity.add(.clean(second, part: .largeFiles))

        model.putBack(model.activity.records[0])
        #expect(Files.exists(items[0].original))
        #expect(model.putBackPending?.items == [items[1]])
        #expect(model.activity.cleaned == 5)
    }
}

struct MacDescriptionTests {
    @Test func theNameAndWhatIsInTheBracketsComeApart() {
        #expect(MacDescription.split("MacBook Pro (16-inch, Nov 2024)") == ("MacBook Pro", "16-inch, Nov 2024"))
        #expect(MacDescription.split("Mac mini") == ("Mac mini", ""))
        let mac = MacDescription(name: "MacBook Pro", edition: "16-inch, Nov 2024", chip: "M4 Pro", memory: 25_769_803_776, system: "macOS 27.0.1")
        #expect(mac.detail == "16-inch, Nov 2024 · M4 Pro · 24 GB memory · macOS 27.0.1")
    }
}
