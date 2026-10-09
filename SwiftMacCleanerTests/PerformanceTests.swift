//
//  PerformanceTests.swift
//  SwiftMacCleanerTests
//
//  The Performance screen: which maintenance tasks are recommended and why, how login items and launch
//  agents are read, and what the plan for running or removing them looks like.
//

import Foundation
import Testing
@testable import SwiftMacCleaner

/// A throwaway folder that stands in for a home directory.
private struct Sandbox {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "mdc-performance-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    @discardableResult
    func plist(_ path: String, _ contents: [String: Any]) throws -> URL {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: contents, format: .xml, options: 0).write(to: url)
        return url
    }
}

private func check(_ task: MaintenanceTask, in checks: [MaintenanceCheck]) -> MaintenanceCheck {
    checks.first { $0.task == task }!
}

/// The readings a disk gives one after another while it hands a reservation back. The last one repeats.
private nonisolated final class Readings {
    private let gigabytes: [Double]
    private(set) var taken = 0

    init(_ gigabytes: [Double]) { self.gigabytes = gigabytes }

    func next() -> DiskInfo {
        let value = gigabytes[min(taken, gigabytes.count - 1)]
        taken += 1
        return DiskInfo(name: "Test", capacity: 500_000_000_000, free: Int64(value * 1_000_000_000))
    }
}

struct PurgeableSpaceTests {
    private func settled(_ readings: Readings, freeBefore: Double, reserved: Double, limit: Int = 100) -> (disk: DiskInfo, isBack: Bool) {
        PurgeableSpace.settled(freeBefore: Int64(freeBefore * 1_000_000_000), reserved: Int64(reserved * 1_000_000_000),
                               readings: limit, pause: {}, measure: readings.next)
    }

    /// What went wrong: the disk was read while it still counted the reservation as used, and a run
    /// that freed space was reported as having lost 53 GB.
    @Test func theDiskIsReadOnceItsReservationIsBack() {
        // Nothing comes back at first, although the reading holds still, and then it comes in steps.
        let readings = Readings([2.6, 2.6, 2.6, 2.6, 2.6, 14, 40, 61, 63.1])
        let result = settled(readings, freeBefore: 62, reserved: 60.4)
        #expect(result.isBack)
        #expect(result.disk.free == 63_100_000_000)
        // No longer than it takes: the readings above, and three more to see that it has stopped rising.
        #expect(readings.taken == 12)
    }

    @Test func aReservationThatDoesNotComeBackIsSaidSo() {
        let readings = Readings([2.6])
        let result = settled(readings, freeBefore: 62, reserved: 60.4, limit: 10)
        #expect(!result.isBack)
        #expect(result.disk.free == 2_600_000_000)
        #expect(readings.taken == 10)
    }

    @Test func nothingReservedMeansNoWaiting() {
        let readings = Readings([62])
        let result = settled(readings, freeBefore: 62, reserved: 0)
        #expect(result.isBack)
        #expect(readings.taken == 1)
    }

    @Test func otherProgramsWritingDoNotHoldUpASmallReservation() {
        // Half a gigabyte was reserved, and something else wrote 50 MB in the meantime.
        let readings = Readings([61.5, 61.95])
        let result = settled(readings, freeBefore: 62, reserved: 0.5)
        #expect(result.isBack)
        #expect(result.disk.free == 61_950_000_000)
        #expect(readings.taken < 10)
    }
}

struct MaintenanceRuleTests {
    let now = Date()

    @Test func everyTaskIsListedOnceInOrder() {
        let checks = MaintenanceScanner.checks(facts: .init(), lastRuns: [:], now: now)
        #expect(checks.map(\.task) == MaintenanceTask.allCases)
    }

    @Test func flushingDNSIsDueWeekly() {
        let never = MaintenanceScanner.checks(facts: .init(), lastRuns: [:], now: now)
        #expect(check(.flushDNS, in: never).isRecommended)
        let recent = MaintenanceScanner.checks(facts: .init(), lastRuns: [.flushDNS: now.addingTimeInterval(-2 * 86_400)], now: now)
        #expect(!check(.flushDNS, in: recent).isRecommended)
        let stale = MaintenanceScanner.checks(facts: .init(), lastRuns: [.flushDNS: now.addingTimeInterval(-9 * 86_400)], now: now)
        #expect(check(.flushDNS, in: stale).isRecommended)
        #expect(check(.flushDNS, in: stale).reason?.contains("9 days ago") == true)
    }

    @Test func purgeableSpaceCountsOnlyWhenThereIsEnough() {
        var facts = MaintenanceScanner.Facts()
        facts.purgeable = 500_000_000
        let little = check(.purgeableSpace, in: MaintenanceScanner.checks(facts: facts, lastRuns: [:], now: now))
        #expect(!little.isRecommended)
        #expect(little.size == 500_000_000)
        facts.purgeable = 4_700_000_000
        let plenty = check(.purgeableSpace, in: MaintenanceScanner.checks(facts: facts, lastRuns: [:], now: now))
        #expect(plenty.isRecommended)
        #expect(plenty.reason?.contains("4.7 GB") == true)
    }

    @Test func mailIsCompactedWhenItsIndexIsLargeAndNotDoneLately() {
        let index = URL(fileURLWithPath: "/Users/demo/Library/Mail/V10/MailData/Envelope Index")
        var facts = MaintenanceScanner.Facts()
        #expect(check(.speedUpMail, in: MaintenanceScanner.checks(facts: facts, lastRuns: [:], now: now)).unavailable != nil)
        facts.mailIndex = .unreadable
        #expect(check(.speedUpMail, in: MaintenanceScanner.checks(facts: facts, lastRuns: [:], now: now)).unavailable?.contains("Full Disk Access") == true)
        facts.mailIndex = .found(index, 50_000_000)
        #expect(!check(.speedUpMail, in: MaintenanceScanner.checks(facts: facts, lastRuns: [:], now: now)).isRecommended)
        facts.mailIndex = .found(index, 1_400_000_000)
        let big = check(.speedUpMail, in: MaintenanceScanner.checks(facts: facts, lastRuns: [:], now: now))
        #expect(big.isRecommended)
        #expect(big.size == 1_400_000_000)
        let lately = MaintenanceScanner.checks(facts: facts, lastRuns: [.speedUpMail: now.addingTimeInterval(-10 * 86_400)], now: now)
        #expect(!check(.speedUpMail, in: lately).isRecommended)
    }

    @Test func memorySpotlightAndToolsDecideTheRest() {
        var facts = MaintenanceScanner.Facts()
        facts.freeMemoryPercent = 18
        facts.spotlightIndexing = false
        facts.hasLaunchServicesTool = false
        let checks = MaintenanceScanner.checks(facts: facts, lastRuns: [:], now: now)
        #expect(check(.freeMemory, in: checks).isRecommended)
        #expect(check(.reindexSpotlight, in: checks).isRecommended)
        #expect(check(.rebuildLaunchServices, in: checks).unavailable != nil)
        #expect(!check(.repairPermissions, in: checks).isRecommended)

        facts.freeMemoryPercent = 61
        facts.spotlightIndexing = nil
        facts.hasLaunchServicesTool = true
        let calm = MaintenanceScanner.checks(facts: facts, lastRuns: [:], now: now)
        #expect(!check(.freeMemory, in: calm).isRecommended)
        #expect(!check(.reindexSpotlight, in: calm).isRecommended)
        #expect(check(.rebuildLaunchServices, in: calm).isAvailable)
    }

    @Test func readsWhatMacOSPrints() {
        #expect(MaintenanceScanner.parseFreeMemory("The system has 2147483648 (524288 pages with a page size of 4096).\n\nSystem-wide memory free percentage: 50%\n") == 50)
        #expect(MaintenanceScanner.parseFreeMemory("nothing here") == nil)
        #expect(MaintenanceScanner.parseSpotlight("/System/Volumes/Data:\n\tIndexing enabled. \n") == true)
        #expect(MaintenanceScanner.parseSpotlight("/:\n\tIndexing disabled.\n") == false)
        #expect(MaintenanceScanner.parseSpotlight("") == nil)
    }

    @Test func findsTheNewestEnvelopeIndex() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        #expect(MaintenanceScanner.mailIndex(home: sandbox.root) == .none)
        let old = sandbox.root.appending(path: "Library/Mail/V9/MailData/Envelope Index")
        let new = sandbox.root.appending(path: "Library/Mail/V10/MailData/Envelope Index")
        for (url, bytes) in [(old, 300), (new, 1_000)] {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(repeating: 1, count: bytes).write(to: url)
        }
        try Data(repeating: 1, count: 24).write(to: URL(fileURLWithPath: new.path + "-wal"))
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-86_400)], ofItemAtPath: old.path)
        #expect(MaintenanceScanner.mailIndex(home: sandbox.root) == .found(new, 1_024))
    }
}

struct LoginItemTests {
    @Test func readsWhatSystemEventsAnswers() throws {
        let json = #"[{"name":"Warp","path":"/Applications/Warp.app","hidden":false},{"name":"","path":"/Applications/Gone.app","hidden":true},{"name":"Nothing","path":"","hidden":false}]"#
        let items = try #require(LoginItemScanner.items(fromJSON: Data(json.utf8)))
        #expect(items.map(\.name) == ["Warp", "Gone"])
        #expect(items[1].isHidden)
        #expect(!items[1].exists)
        #expect(LoginItemScanner.items(fromJSON: Data("not json".utf8)) == nil)
    }

    @Test func removalNamesThePathAndEscapesIt() {
        let item = LoginItem(name: "Odd", path: URL(fileURLWithPath: "/Applications/Say \"hi\".app"))
        let command = LoginItemScanner.removeCommand(for: item)
        #expect(command.first == "/usr/bin/osascript")
        #expect(command.last?.contains(#"whose path is "/Applications/Say \"hi\".app""#) == true)
        #expect(LoginItemScanner.failureReason("execution error: Not authorized to send Apple events to System Events. (-1743)").contains("Automation"))
    }
}

struct BackgroundItemTests {
    @Test func readsAPlistIntoAnItem() {
        let plist: [String: Any] = [
            "Label": "us.zoom.updater",
            "ProgramArguments": ["/Applications/zoom.us.app/Contents/Library/LaunchAgents/ZoomUpdater.app/Contents/MacOS/ZoomUpdater", "--update"],
            "RunAtLoad": false, "KeepAlive": ["SuccessfulExit": false], "StartInterval": 3600,
        ]
        let url = URL(fileURLWithPath: "/Library/LaunchAgents/us.zoom.updater.plist")
        let item = BackgroundItemScanner.item(from: plist, at: url, domain: .systemAgent) { _ in nil }!
        #expect(item.label == "us.zoom.updater")
        #expect(item.program?.hasSuffix("/ZoomUpdater") == true)
        // The helper sits inside the app, so the app is the owner, not the helper.
        #expect(item.appURL == URL(fileURLWithPath: "/Applications/zoom.us.app", isDirectory: true))
        #expect(item.appName == "zoom.us")
        #expect(item.keepsAlive)
        #expect(item.interval == 3600)
        #expect(item.schedule == "every 60 minutes, kept running")
        #expect(item.needsPassword)
        #expect(!item.domain.runsAsRoot)
    }

    @Test func anAssociatedAppIsLookedUpWhenTheProgramIsNotInsideOne() {
        let plist: [String: Any] = [
            "Label": "com.google.GoogleUpdater.wake", "AssociatedBundleIdentifiers": ["com.google.GoogleUpdater"],
            "ProgramArguments": ["/Library/Google/GoogleUpdater/Current/GoogleUpdater", "--wake-all"], "StartInterval": 7200,
        ]
        let url = URL(fileURLWithPath: "/Users/demo/Library/LaunchAgents/com.google.GoogleUpdater.wake.plist")
        let item = BackgroundItemScanner.item(from: plist, at: url, domain: .userAgent) { id in
            id == "com.google.GoogleUpdater" ? URL(fileURLWithPath: "/Applications/Google Updater.app") : nil
        }!
        #expect(item.appName == "Google Updater")
        #expect(item.schedule == "every 2 hours")
        #expect(!item.needsPassword)
        #expect(BackgroundItemScanner.item(from: ["Program": "/bin/true"], at: url, domain: .userAgent) { _ in nil } == nil)
    }

    @Test func readsTheDisabledFlagAndTheWatchTriggers() {
        let plist: [String: Any] = [
            "Label": "com.example.watcher", "BundleProgram": "Contents/MacOS/watcher", "Disabled": true,
            "WatchPaths": ["/Users/demo/Library/Preferences/com.example.plist"], "QueueDirectories": ["/Users/demo/Drop"],
            "StartCalendarInterval": ["Hour": 3],
        ]
        let url = URL(fileURLWithPath: "/Users/demo/Library/LaunchAgents/com.example.watcher.plist")
        let item = BackgroundItemScanner.item(from: plist, at: url, domain: .userAgent) { _ in nil }!
        #expect(item.program == "Contents/MacOS/watcher")
        #expect(item.isDisabled)
        #expect(item.schedule == "on a schedule, when a watched file changes, when a watched folder fills")
        #expect(item.state == "disabled")
        var running = item
        running.isRunning = true
        #expect(running.state == "running now")
    }

    @Test func appleAndOwnServicesAreLeftOut() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let agents = sandbox.root.appending(path: "Library/LaunchAgents")
        try sandbox.plist("Library/LaunchAgents/com.apple.something.plist", ["Label": "com.apple.something", "Program": "/usr/bin/true"])
        try sandbox.plist("Library/LaunchAgents/com.thetinydev.SwiftMacCleaner.check.plist", ["Label": "com.thetinydev.SwiftMacCleaner.check", "Program": "/usr/bin/true"])
        try sandbox.plist("Library/LaunchAgents/org.example.sync.plist", ["Label": "org.example.sync", "Program": "/usr/local/bin/sync", "RunAtLoad": true])
        try sandbox.plist("Library/LaunchAgents/org.example.idle.plist", ["Label": "org.example.idle", "Program": "/usr/local/bin/idle"])
        try sandbox.plist("Library/LaunchAgents/broken.plist", ["NoLabel": true])
        var loaded = BackgroundItemScanner.Loaded()
        loaded.user = ["org.example.sync": 4242]
        loaded.asked = true

        let scan = await BackgroundItemScanner.scan(
            home: sandbox.root, ownBundleID: "com.thetinydev.SwiftMacCleaner",
            folders: [.init(url: agents, domain: .userAgent)], loaded: loaded, appLookup: { _ in nil }
        )
        let items = scan.items
        #expect(items.map(\.label) == ["org.example.idle", "org.example.sync"])
        #expect(items[1].isLoaded == true)
        #expect(items[1].isRunning)
        #expect(items[1].detail == "Launch agent · starts at login · running now")
        #expect(items[0].isLoaded == false)
        #expect(items[0].state == "not loaded")
        // The plist without a label is reported, not silently dropped.
        #expect(scan.issues == ["broken.plist in ~/Library/LaunchAgents names no service, so launchd ignores it."])
    }

    @Test func whatCannotBeReadIsReportedRatherThanDropped() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let locked = sandbox.root.appending(path: "Library/LaunchDaemons")
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        try sandbox.plist("Library/LaunchDaemons/org.example.locked.plist", ["Label": "org.example.locked", "Program": "/usr/bin/true"])
        try FileManager.default.createDirectory(at: sandbox.root.appending(path: "Library/LaunchAgents"), withIntermediateDirectories: true)
        try Data("not a plist".utf8).write(to: sandbox.root.appending(path: "Library/LaunchAgents/garbage.plist"), options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }

        let scan = await BackgroundItemScanner.scan(
            home: sandbox.root, ownBundleID: "x",
            folders: [
                .init(url: sandbox.root.appending(path: "Library/LaunchAgents"), domain: .userAgent),
                .init(url: locked, domain: .systemDaemon),
                .init(url: sandbox.root.appending(path: "Library/Missing"), domain: .systemAgent),
            ],
            loaded: BackgroundItemScanner.Loaded(), appLookup: { _ in nil }
        )
        #expect(scan.items.isEmpty)
        #expect(scan.issues.count == 3)
        #expect(scan.issues[0].hasPrefix("launchd could not be asked"))
        #expect(scan.issues[1] == "garbage.plist in ~/Library/LaunchAgents is not a property list launchd could read.")
        #expect(scan.issues[2].hasPrefix("~/Library/LaunchDaemons could not be read"))
    }

    @Test func readsLaunchdTables() {
        let list = "PID\tStatus\tLabel\n740\t0\tcom.example.cleaner.Menu\n-\t0\tus.zoom.updater\n-\t-9\tcom.example.crashed\n"
        let user = BackgroundItemScanner.parseServices(list)
        #expect(user["com.example.cleaner.Menu"] == 740)
        #expect(user["us.zoom.updater"] == .some(nil))
        #expect(user["com.example.crashed"] == .some(nil))
        #expect(user["Label"] == nil)
        let system = "com.apple.xpc.launchd.domain.system = {\n\tservices = {\n\t\t     593      - \torg.openvpn.helper\n\t\t       0      0 \tcom.docker.socket\n\t}\n}\n"
        let daemons = BackgroundItemScanner.parseServices(system)
        #expect(daemons["org.openvpn.helper"] == 593)
        #expect(daemons["com.docker.socket"] == .some(nil))
    }
}

struct PerformancePlanTests {
    private func checks(_ unavailable: Set<MaintenanceTask> = []) -> [MaintenanceCheck] {
        MaintenanceTask.allCases.map { task in
            MaintenanceCheck(task: task, reason: nil, size: task == .purgeableSpace ? 4_000_000_000 : 0,
                             unavailable: unavailable.contains(task) ? "Not here" : nil)
        }
    }

    @Test func rootTasksShareOneStepAndTheOthersGetTheirOwn() {
        let plan = PerformancePlan.tasks(checks(), selection: [.flushDNS, .freeMemory, .speedUpMail, .purgeableSpace],
                                         mailIndex: URL(fileURLWithPath: "/Users/demo/Envelope Index"), executable: "/Applications/X.app/Contents/MacOS/X", uid: 501)
        #expect(plan.steps.map(\.id) == [PerformancePlan.adminTasksStepID, "maintenance/purgeableSpace", "maintenance/speedUpMail"])
        #expect(plan.needsPassword)
        let admin = plan.steps[0]
        #expect(admin.title == "Flush DNS Cache and Free Up Memory")
        guard case .runAsAdmin(let command) = admin.operations.first?.kind else { Issue.record("not an admin command"); return }
        #expect(command.prefix(2) == ["/bin/sh", "-c"])
        #expect(command[2].contains("dscacheutil -flushcache"))
        #expect(command[2].contains("/usr/sbin/purge"))
        #expect(command[2].contains("failed=\"$failed flushDNS\""))
        #expect(command[2].hasSuffix("exit 1; fi"))
        #expect(plan.steps[1].size == 4_000_000_000)
        guard case .run(let purge) = plan.steps[1].operations.first?.kind else { Issue.record("not a command"); return }
        #expect(purge == ["/Applications/X.app/Contents/MacOS/X", "--free-purgeable"])
        #expect(plan.steps[2].waitsFor == .app(bundleID: "com.apple.mail", name: "Mail"))
        guard case .run(let vacuum) = plan.steps[2].operations.first?.kind else { Issue.record("not a command"); return }
        #expect(vacuum == ["/usr/bin/sqlite3", "/Users/demo/Envelope Index", "VACUUM; REINDEX;"])
    }

    @Test func unavailableTasksAreLeftOutAndFailuresAreReadBack() {
        let plan = PerformancePlan.tasks(checks([.speedUpMail]), selection: [.speedUpMail, .rebuildLaunchServices],
                                         mailIndex: nil, executable: "/x", uid: 501)
        #expect(plan.steps.map(\.id) == ["maintenance/rebuildLaunchServices"])
        #expect(!plan.needsPassword)
        let failure = "sh failed: failed: flushDNS repairPermissions"
        #expect(PerformancePlan.failedTasks(in: failure) == [.flushDNS, .repairPermissions])
        #expect(PerformancePlan.failedTasks(in: "sh was skipped: the password prompt was cancelled").isEmpty)
    }

    @Test func aUserAgentIsUnloadedThenTrashed() {
        let home = URL(fileURLWithPath: "/Users/demo")
        var item = BackgroundItem(plist: home.appending(path: "Library/LaunchAgents/com.example.sync.plist"), label: "com.example.sync", domain: .userAgent)
        item.isLoaded = true
        let loaded = PerformancePlan.backgroundItems([item], selection: [item.id], home: home, uid: 501)
        #expect(loaded.steps.count == 1)
        #expect(loaded.steps[0].method == .trash)
        #expect(loaded.steps[0].operations.map(\.kind) == [.run(["/bin/launchctl", "bootout", "gui/501/com.example.sync"]), .trash(item.plist)])

        item.isLoaded = false
        let unloaded = PerformancePlan.backgroundItems([item], selection: [item.id], home: home, uid: 501)
        #expect(unloaded.steps[0].operations.map(\.kind) == [.trash(item.plist)])

        item.isLoaded = nil
        let unknown = PerformancePlan.backgroundItems([item], selection: [item.id], home: home, uid: 501)
        guard case .run(let command) = unknown.steps[0].operations.first?.kind else { Issue.record("not a command"); return }
        #expect(command[2].hasSuffix("|| true"))
        #expect(PerformancePlan.backgroundItems([item], selection: [], home: home, uid: 501).isEmpty)
    }

    @Test func aDaemonIsRemovedWithThePassword() {
        let home = URL(fileURLWithPath: "/Users/demo")
        let item = BackgroundItem(plist: URL(fileURLWithPath: "/Library/LaunchDaemons/com.example.vmnetd.plist"), label: "com.example.vmnetd", domain: .systemDaemon)
        let plan = PerformancePlan.backgroundItems([item], selection: [item.id], home: home, uid: 501)
        #expect(plan.steps[0].method == .adminCommand)
        #expect(plan.needsPassword)
        guard case .runAsAdmin(let command) = plan.steps[0].operations.first?.kind else { Issue.record("not an admin command"); return }
        #expect(command[2].contains("launchctl bootout 'system/com.example.vmnetd'"))
        #expect(command[2].contains("/bin/mv -f '/Library/LaunchDaemons/com.example.vmnetd.plist'"))
        #expect(command[2].contains("/usr/sbin/chown 501"))
        #expect(command[2].contains("/Users/demo/.Trash/com.example.vmnetd.plist"))
    }

    @Test func loginItemsBecomeCommands() {
        let items = [LoginItem(name: "Warp", path: URL(fileURLWithPath: "/Applications/Warp.app")),
                     LoginItem(name: "Other", path: URL(fileURLWithPath: "/Applications/Other.app"))]
        let plan = PerformancePlan.loginItems(items, selection: [items[1].id])
        #expect(plan.steps.map(\.title) == ["Other"])
        #expect(plan.steps[0].method == .command)
        #expect(!plan.needsPassword)
    }
}
