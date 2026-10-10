//
//  SharedTempTests.swift
//  SwiftMacCleanerTests
//
//  The temp folder every program shares: what in it is offered, what is left to the programs still
//  using it, and that the same question is asked again just before anything is removed.
//

import Foundation
import Testing
@testable import SwiftMacCleaner

/// A throwaway folder that stands in for /private/tmp, beside one that stands in for the home folder.
private struct Temp {
    let root: URL
    let home: URL
    let now = Date()

    init() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: "mdc-tmp-\(UUID().uuidString)").resolvingSymlinksInPath()
        root = base.appending(path: "tmp")
        home = base.appending(path: "home")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    func remove() { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }

    var context: ScanContext { ScanContext(home: home, now: now) }
    /// Small enough for a test to write: 100 KB to be offered, 400 KB to be listed when left alone.
    var sizes: SharedTempScanner.Sizes { SharedTempScanner.Sizes(minimum: 100_000, listed: 400_000) }

    @discardableResult
    func file(_ path: String, kilobytes: Int = 150) throws -> URL {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 9, count: kilobytes * 1_000).write(to: url)
        return url
    }

    /// Makes the item, and everything inside it, look last changed that many days ago. A folder's own
    /// date counts as a change to it, so the folders are dated too.
    func age(_ path: String, days: Double) throws {
        let url = root.appending(path: path)
        let date = now.addingTimeInterval(-days * 86_400)
        let inside = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        for item in inside + [url] {
            try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: item.path)
        }
    }

    func scan(openFiles: OpenFiles = OpenFiles(), uid: uid_t = getuid()) -> SharedTempScanner.Offers {
        SharedTempScanner.scan(context, root: root, uid: uid, openFiles: openFiles, sizes: sizes)
    }
}

private func titles(_ items: [FindingItem]) -> [String] { items.map(\.title).sorted() }

struct OpenFilesTests {
    @Test func seesWhatARunningProgramHasOpen() throws {
        let temp = try Temp()
        defer { temp.remove() }
        let held = try temp.file("session/output.log")
        let other = try temp.file("other/output.log")

        let handle = try FileHandle(forReadingFrom: held)
        let open = OpenFiles.snapshot(under: [temp.root])
        #expect(open.isInUse(held))
        // The folder a file is in counts as in use, and so does every folder above it.
        #expect(open.isInUse(held.deletingLastPathComponent()))
        #expect(open.isInUse(temp.root))
        #expect(!open.isInUse(other))
        #expect(!open.isInUse(other.deletingLastPathComponent()))
        // A folder whose name merely starts the same is another folder.
        #expect(!open.isInUse(temp.root.appending(path: "sess")))

        try handle.close()
        #expect(!OpenFiles.snapshot(under: [temp.root]).isInUse(held))
        // Nothing to look under, nothing found.
        #expect(!OpenFiles.snapshot(under: []).isInUse(held))
    }

    @Test func writesAPathOneWayHoweverItWasReported() {
        #expect(OpenFiles.canonical("/private/tmp/work/a") == "/tmp/work/a")
        #expect(OpenFiles.canonical("/private/var/folders/x/T") == "/var/folders/x/T")
        #expect(OpenFiles.canonical("/private/tmp") == "/tmp")
        #expect(OpenFiles.canonical("/private/tmpfiles/a") == "/private/tmpfiles/a")
        #expect(OpenFiles.canonical("/Users/someone/tmp") == "/Users/someone/tmp")
        let open = OpenFiles(paths: ["/private/tmp/work/session/log"])
        #expect(open.isInUse(URL(fileURLWithPath: "/tmp/work")))
        #expect(open.isInUse(URL(fileURLWithPath: "/private/tmp/work/session")))
        #expect(!open.isInUse(URL(fileURLWithPath: "/private/tmp/workshop")))
    }
}

struct SharedTempScannerTests {
    @Test func offersWhatHasSatIdleAndTicksOnlyWhatHasSatAWeek() throws {
        let temp = try Temp()
        defer { temp.remove() }
        try temp.file("old-build/objects.bin")
        try temp.file("dump.bin", kilobytes: 300)
        try temp.file("yesterday/cache.bin")
        try temp.file("note.bin")
        try temp.file("today/cache.bin", kilobytes: 500)
        try temp.file("small/readme.txt", kilobytes: 20)
        try temp.age("old-build", days: 10)
        try temp.age("dump.bin", days: 8)
        try temp.age("yesterday", days: 2)
        try temp.age("note.bin", days: 1.5)
        try temp.age("small", days: 30)

        let offers = temp.scan()
        // A week untouched: as settled as anything in the per-user temp folders, largest first.
        #expect(offers.settled.map(\.title) == ["dump.bin", "old-build"])
        // A day untouched: offered, but for the user to look at.
        #expect(titles(offers.idle) == ["note.bin", "yesterday"])
        #expect(offers.idle.first?.detail.hasPrefix("In \(temp.root.path), untouched since") == true)
        #expect(offers.idle.allSatisfy { $0.paths.count == 1 })
        // Written to today, so it is left alone, and said to be because it is big.
        #expect(offers.protected.map(\.title) == ["today"])
        #expect(offers.protected.first?.rule == .recentlyUsed)

        let finding = try #require(SharedTempScanner.finding(for: offers.idle, root: temp.root))
        #expect(finding.tier == .review)
        #expect(finding.method == .trash)
        #expect([finding].safeDefaults.isEmpty)
        #expect(SharedTempScanner.finding(for: []) == nil)
    }

    /// One folder per session of some tool, in a folder that is itself written to all day.
    @Test func looksForIdleFoldersInsideABusyOneThreeLevelsDown() throws {
        let temp = try Temp()
        defer { temp.remove() }
        try temp.file("tool/project-a/session-1/build.bin")
        try temp.file("tool/project-a/session-2/build.bin")
        try temp.file("tool/project-b/session-3/build.bin")
        try temp.file("tool/project-b/session-4/deep/idle/build.bin")
        try temp.file("tool/project-b/session-4/deep/busy/build.bin")
        try temp.age("tool/project-a", days: 3)
        try temp.age("tool/project-b/session-3", days: 2)
        try temp.age("tool/project-b/session-4/deep/idle", days: 5)

        let offers = temp.scan()
        #expect(offers.settled.isEmpty)
        // A project with nothing going on is offered whole. In the busy one, the idle session alone.
        #expect(titles(offers.idle) == ["project-a", "session-3"])
        #expect(offers.idle.first { $0.title == "session-3" }?.detail.contains("/tool/project-b,") == true)
        // The idle folder four levels down is part of a session that is still running.
        #expect(!offers.idle.contains { $0.paths.contains { $0.path.contains("session-4") } })

        // A week on, with only the newest session still written to, the rest of its project is offered too.
        try temp.age("tool", days: 9)
        try temp.file("tool/project-b/session-4/deep/busy/more.bin")
        let later = temp.scan()
        // Inside a folder that is still busy nothing is ticked, however long it has sat.
        #expect(later.settled.isEmpty)
        #expect(titles(later.idle) == ["project-a", "session-3"])
    }

    @Test func leavesAloneWhatProgramsTalkThroughOrHaveOpen() throws {
        let temp = try Temp()
        defer { temp.remove() }
        try temp.file("ipc/state.bin", kilobytes: 500)
        #expect(mkfifo(temp.root.appending(path: "ipc/control").path, 0o600) == 0)
        try temp.file("bridge/a/pipe-holder/state.bin")
        try temp.file("bridge/b/work.bin")
        #expect(mkfifo(temp.root.appending(path: "bridge/a/pipe-holder/control").path, 0o600) == 0)
        let held = try temp.file("held/session/output.log", kilobytes: 500)
        try temp.file("held/other-session/output.log")
        try temp.file(".hidden/cache.bin")
        try temp.file("com.apple.launchd.abc/cache.bin")
        for name in ["ipc", "bridge", "held", ".hidden", "com.apple.launchd.abc"] { try temp.age(name, days: 3) }

        let handle = try FileHandle(forReadingFrom: held)
        defer { try? handle.close() }
        let offers = temp.scan(openFiles: OpenFiles.snapshot(under: [temp.root]))
        // A folder with a pipe directly in it is left whole. One with a pipe further down is looked
        // into, and what has no pipe in it is offered.
        // In the folder with a file held open, the session beside that one is free to go.
        #expect(titles(offers.idle) == ["b", "other-session"])
        #expect(offers.settled.isEmpty)
        #expect(Set(offers.protected.map(\.title)) == ["ipc", "session"])
        #expect(offers.protected.allSatisfy { $0.rule == .inUse })
        #expect(offers.protected.first { $0.title == "session" }?.why.contains("has files open") == true)
        #expect(offers.protected.first { $0.title == "ipc" }?.why.contains("socket or pipe") == true)

        // With the file closed, the folder it was in is as idle as the rest and is offered whole.
        try handle.close()
        #expect(titles(temp.scan(openFiles: OpenFiles.snapshot(under: [temp.root])).idle) == ["b", "held"])
    }

    @Test func offersNothingThatBelongsToSomeoneElse() throws {
        let temp = try Temp()
        defer { temp.remove() }
        try temp.file("theirs/cache.bin", kilobytes: 500)
        try temp.file("theirs.bin", kilobytes: 500)
        try temp.age("theirs", days: 10)
        try temp.age("theirs.bin", days: 10)
        // Seen as another user would see it: nothing at the top is theirs.
        let offers = temp.scan(uid: getuid() + 1)
        #expect(offers.settled.isEmpty && offers.idle.isEmpty && offers.protected.isEmpty)
        #expect(temp.scan().settled.count == 2)
    }
}

struct TempRemovalTests {
    @Test func theGuardReachesIntoTheTempFolderButNeverTakesItWhole() throws {
        let temp = try Temp()
        defer { temp.remove() }
        let item = try temp.file("work/cache.bin")
        let safety = SafetyGuard(root: temp.home, extraRoots: [temp.root])
        #expect(safety.allows(item))
        #expect(safety.allows(item.deletingLastPathComponent()))
        #expect(safety.refusal(for: temp.root) != nil)
        #expect(SafetyGuard(root: temp.home).refusal(for: item) == "outside the allowed area")
        // The real one is among the folders a clean-up may reach into, beside the per-user ones.
        #expect(GuardRoots.temporaryFolders().contains(GuardRoots.sharedTemporaryFolder))
        #expect(GuardRoots.temporaryFolders().count == GuardRoots.userTemporaryFolders().count + 1)
    }

    /// The scan asked what was open; by the time something is removed, a program may have come back to it.
    @Test func whatAProgramHasOpenIsLeftAloneAtTheMomentOfRemoval() async throws {
        let temp = try Temp()
        defer { temp.remove() }
        let held = try temp.file("held/output.log")
        let free = try temp.file("free/output.log")
        // In the home folder the question is not asked: a cache is cleared while its app runs, as before.
        let cache = temp.home.appending(path: "Library/Caches/com.example.app/data.bin")
        try FileManager.default.createDirectory(at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 1, count: 1_000).write(to: cache)
        let safety = SafetyGuard(root: temp.home, extraRoots: [temp.root])
        let plan = CleanPlan(steps: [CleanStep(
            id: "caches.tmp", title: "Idle work folders", tier: .review, method: .delete, summary: "", size: 0,
            operations: [
                CleanOperation(itemID: "held", kind: .delete(held.deletingLastPathComponent())),
                CleanOperation(itemID: "free", kind: .delete(free.deletingLastPathComponent())),
                CleanOperation(itemID: "cache", kind: .delete(cache.deletingLastPathComponent())),
            ]
        )])

        let handles = [try FileHandle(forReadingFrom: held), try FileHandle(forReadingFrom: cache)]
        let outcome = await Cleaner.run(plan: plan, safety: safety) { _ in }
        let step = try #require(outcome.steps.first)
        #expect(step.cleanedItemIDs == ["free", "cache"])
        #expect(step.skippedItems.keys.sorted() == ["held"])
        #expect(step.skippedItems["held"]?.contains(Cleaner.inUseReason) == true)
        #expect(step.failures.isEmpty)
        #expect(Files.exists(held) && !Files.exists(free) && !Files.exists(cache))

        // Once nothing holds it, the same plan takes it.
        for handle in handles { try handle.close() }
        let second = await Cleaner.run(plan: plan, safety: safety) { _ in }
        #expect(second.steps.first?.skippedItems.isEmpty == true)
        #expect(!Files.exists(held))
    }
}
