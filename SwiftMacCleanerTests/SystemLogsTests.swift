//
//  SystemLogsTests.swift
//  SwiftMacCleanerTests
//
//  The old logs that belong to root. Nothing here asks for a password: the scan is run over a stand-in
//  for /Library/Logs and /private/var/log, and the script root would run is run as the tests' own user
//  over the same stand-in.
//

import Foundation
import Testing
@testable import SwiftMacCleaner

/// A throwaway stand-in for the folders root keeps logs in.
private struct LogSandbox {
    let root: URL

    var logs: URL { root.appending(path: "Library/Logs") }
    var systemLog: URL { root.appending(path: "private/var/log") }
    var roots: [URL] { [logs, systemLog] }

    init() throws {
        let made = FileManager.default.temporaryDirectory.appending(path: "mdc-logs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: made, withIntermediateDirectories: true)
        // The script goes by the path the kernel gives a folder, and the temp folder is reached through a link.
        root = URL(fileURLWithPath: try #require(SystemLogs.physicalPath(of: made.path)), isDirectory: true)
        for folder in [logs, systemLog] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    func target(_ root: URL, _ folder: String? = nil) -> SystemLogs.Target {
        SystemLogs.Target(root: root, folder: folder)
    }

    /// Writes a file of the given size that was last written to `days` ago.
    @discardableResult
    func file(_ url: URL, megabytes: Double = 0.1, age days: Double) throws -> URL {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 7, count: Int(megabytes * 1_000_000)).write(to: url)
        let date = Date().addingTimeInterval(-days * 86_400)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        return url
    }

    @discardableResult
    func folder(_ url: URL) throws -> URL {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Runs what root would be handed, as the user the tests run as.
    func run(_ targets: [SystemLogs.Target]) throws -> Shell.Output {
        let command = SystemLogs.command(for: targets)
        return try #require(Shell.run(command[0], Array(command.dropFirst()), timeout: 60))
    }

    /// Every file under the sandbox, by its path from there, for seeing that nothing unexpected turned up.
    func everything() -> Set<String> {
        let all = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        return Set(all.map { String($0.path.dropFirst(root.path.count + 1)) })
    }
}

struct SystemLogsTests {
    @Test func oldLogsAreOfferedAndNothingElse() async throws {
        let sandbox = try LogSandbox()
        defer { sandbox.remove() }
        let crashes = sandbox.logs.appending(path: "CrashReporter")
        try sandbox.file(crashes.appending(path: "old.log"), megabytes: 4, age: 30)
        try sandbox.file(crashes.appending(path: "deeper/older.log"), megabytes: 4, age: 9)
        try sandbox.file(crashes.appending(path: "written-today.log"), megabytes: 4, age: 0)
        try sandbox.file(sandbox.logs.appending(path: "Quiet/small.log"), megabytes: 0.2, age: 30)
        try sandbox.file(sandbox.systemLog.appending(path: "system.log"), megabytes: 2, age: 0)
        try sandbox.file(sandbox.systemLog.appending(path: "system.log.0.gz"), megabytes: 2, age: 8)
        try sandbox.file(sandbox.systemLog.appending(path: "asl/last-month.asl"), megabytes: 3, age: 30)

        let finding = try #require(await SystemLogs.finding(ScanContext(home: sandbox.root), roots: sandbox.roots))
        #expect(finding.id == SystemLogs.findingID)
        #expect(finding.area == .cachesLogs)
        #expect(finding.method == .adminDelete)
        #expect(finding.aftermath == .rebuilds)
        #expect(finding.smart == .systemLogs)

        // Largest first: the crash logs less the one written today, the old ASL store, then the rotated
        // log lying loose. The quiet folder is too small for a row.
        #expect(finding.items.map(\.title) == ["CrashReporter", "asl", "Old log files in \(sandbox.systemLog.path)"])
        #expect(finding.items.map(\.systemTarget) == [
            sandbox.target(sandbox.logs, "CrashReporter"), sandbox.target(sandbox.systemLog, "asl"), sandbox.target(sandbox.systemLog),
        ])
        let crashReporter = try #require(finding.items.first)
        #expect(crashReporter.size >= 8_000_000 && crashReporter.size < 9_000_000)
        #expect(crashReporter.detail.contains("2 files untouched for 7+ days"))
        #expect(crashReporter.paths.map(\.path) == [crashes.path])
        for item in finding.items {
            let target = try #require(item.systemTarget)
            #expect(SystemLogs.allows(target, roots: sandbox.roots))
        }
    }

    @Test func tooLittleIsNotWorthAPassword() async throws {
        let sandbox = try LogSandbox()
        defer { sandbox.remove() }
        try sandbox.file(sandbox.logs.appending(path: "CrashReporter/old.log"), megabytes: 3, age: 30)
        #expect(await SystemLogs.finding(ScanContext(home: sandbox.root), roots: sandbox.roots) == nil)
    }

    /// Unless a scan is told where root keeps its logs, as the app's own settings tell it, it does not look.
    @Test func aScanOnlyLooksWhenItIsToldWhere() async throws {
        let sandbox = try LogSandbox()
        defer { sandbox.remove() }
        try sandbox.file(sandbox.logs.appending(path: "CrashReporter/old.log"), megabytes: 12, age: 30)
        var context = ScanContext(home: sandbox.root)
        let without = await CachesLogsScanner.scan(context).findings.map(\.id)
        #expect(!without.contains(SystemLogs.findingID))
        context.systemLogRoots = sandbox.roots
        let with = await CachesLogsScanner.scan(context).findings.map(\.id)
        #expect(with.contains(SystemLogs.findingID))
    }

    @Test func rootIsOnlyAskedToReachIntoFoldersThatWereLookedAt() throws {
        let sandbox = try LogSandbox()
        defer { sandbox.remove() }
        let roots = sandbox.roots
        let crashes = try sandbox.folder(sandbox.logs.appending(path: "CrashReporter"))
        try sandbox.folder(crashes.appending(path: "deeper"))
        try sandbox.folder(sandbox.logs.appending(path: ".hidden"))
        try sandbox.file(sandbox.logs.appending(path: "setup.log"), age: 30)
        let elsewhere = try sandbox.folder(sandbox.root.appending(path: "Users/someone/Documents"))
        try FileManager.default.createSymbolicLink(at: sandbox.logs.appending(path: "Link"), withDestinationURL: elsewhere)

        func allows(_ root: URL, _ folder: String? = nil) -> Bool {
            SystemLogs.allows(sandbox.target(root, folder), roots: roots)
        }
        // A root itself, for its loose files, and a real folder directly inside one.
        #expect(allows(sandbox.logs))
        #expect(allows(sandbox.systemLog))
        #expect(allows(sandbox.logs, "CrashReporter"))
        // Never deeper, never a file or a link, never a name that hides or climbs.
        #expect(!allows(sandbox.logs, "CrashReporter/deeper"))
        #expect(!allows(sandbox.logs, ".hidden"))
        #expect(!allows(sandbox.logs, "setup.log"))
        #expect(!allows(sandbox.logs, "Link"))
        #expect(!allows(sandbox.logs, "Missing"))
        #expect(!allows(sandbox.logs, ".."))
        #expect(!allows(sandbox.logs, "../../Users/someone/Documents"))
        #expect(!allows(sandbox.logs, ""))
        #expect(!allows(sandbox.logs, "Crash\nReporter"))
        // Never a folder that is not one of the roots, however it is spelled.
        #expect(!allows(elsewhere))
        #expect(!allows(sandbox.root, "Library"))
        #expect(!allows(crashes))
        #expect(!allows(sandbox.logs.appending(path: "CrashReporter/.."), "CrashReporter"))
        // A root named through a link is not the path the kernel gives it, so it is refused as well.
        let alias = sandbox.root.appending(path: "alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: sandbox.logs)
        #expect(!SystemLogs.allows(sandbox.target(alias, "CrashReporter"), roots: [alias]))
        // The real ones are named the way the kernel names them.
        for root in SystemLogs.roots {
            #expect(SystemLogs.physicalPath(of: root.path) == root.path)
        }
    }

    @Test func theScriptDeletesOldFilesAndKeepsNewOnesAndEveryFolder() throws {
        let sandbox = try LogSandbox()
        defer { sandbox.remove() }
        let crashes = sandbox.logs.appending(path: "CrashReporter")
        let old = try sandbox.file(crashes.appending(path: "old.log"), age: 30)
        let deep = try sandbox.file(crashes.appending(path: "a/b/c/older.log"), age: 9)
        let fresh = try sandbox.file(crashes.appending(path: "written-today.log"), age: 0)
        let recent = try sandbox.file(crashes.appending(path: "a/last-week.log"), age: 5)
        let hiddenOld = try sandbox.file(crashes.appending(path: ".cache/old.bin"), age: 30)
        let untouched = try sandbox.file(sandbox.logs.appending(path: "Other/old.log"), age: 30)
        let looseOld = try sandbox.file(sandbox.systemLog.appending(path: "system.log.0.gz"), age: 8)
        let looseNew = try sandbox.file(sandbox.systemLog.appending(path: "system.log"), age: 0)
        let inFolder = try sandbox.file(sandbox.systemLog.appending(path: "asl/last-month.asl"), age: 30)
        // Something of the user's that links inside a log folder point at.
        let precious = try sandbox.file(sandbox.root.appending(path: "Users/someone/Documents/thesis.txt"), age: 400)
        try FileManager.default.createSymbolicLink(at: crashes.appending(path: "shortcut"), withDestinationURL: precious)
        try FileManager.default.createSymbolicLink(at: crashes.appending(path: "a/folder-shortcut"),
                                                   withDestinationURL: precious.deletingLastPathComponent())

        let output = try sandbox.run([sandbox.target(sandbox.logs, "CrashReporter"), sandbox.target(sandbox.systemLog)])
        #expect(output.status == 0, "\(output.stderr)")

        #expect(!Files.exists(old))
        #expect(!Files.exists(deep))
        #expect(!Files.exists(hiddenOld))
        #expect(Files.exists(fresh))
        #expect(Files.exists(recent))
        // Every folder stays, emptied or not.
        #expect(Files.isDirectory(crashes))
        #expect(Files.isDirectory(deep.deletingLastPathComponent()))
        #expect(Files.isDirectory(hiddenOld.deletingLastPathComponent()))
        // Loose means loose: the folder beside the loose files was not gone into.
        #expect(!Files.exists(looseOld))
        #expect(Files.exists(looseNew))
        #expect(Files.exists(inFolder))
        // A folder that was not named is not touched, and a link is neither followed nor removed.
        #expect(Files.exists(untouched))
        #expect(Files.exists(precious))
        #expect(Files.isSymlink(crashes.appending(path: "shortcut")))
        #expect(Files.isSymlink(crashes.appending(path: "a/folder-shortcut")))
    }

    /// Between the scan and the clean a folder can be swapped for a link, by something that hopes root
    /// will follow it. The guard refuses one it sees; one that gets as far as the script is entered,
    /// found not to be where it should be, and left alone.
    @Test func aFolderThatBecameALinkIsEnteredAndLeftAlone() throws {
        let sandbox = try LogSandbox()
        defer { sandbox.remove() }
        let documents = try sandbox.folder(sandbox.root.appending(path: "Users/someone/Documents"))
        let precious = try sandbox.file(documents.appending(path: "thesis.txt"), age: 400)
        let deeper = try sandbox.file(documents.appending(path: "years/ago/letter.txt"), age: 900)
        try FileManager.default.createSymbolicLink(at: sandbox.logs.appending(path: "CrashReporter"), withDestinationURL: documents)
        let honest = try sandbox.file(sandbox.logs.appending(path: "Honest/old.log"), age: 30)
        #expect(!SystemLogs.allows(sandbox.target(sandbox.logs, "CrashReporter"), roots: sandbox.roots))

        let output = try sandbox.run([
            sandbox.target(sandbox.logs, "CrashReporter"),
            sandbox.target(sandbox.logs, "Gone"),
            sandbox.target(sandbox.logs, "Honest"),
        ])
        // The link is reported as unfinished, the folder that is gone is not, and the honest one was cleaned.
        #expect(output.status != 0)
        #expect(SystemLogs.failedPositions(in: output.stderr) == [0])
        #expect(Files.exists(precious))
        #expect(Files.exists(deeper))
        #expect(!Files.exists(honest))

        // A root that is itself reached through a link is treated the same way.
        let alias = sandbox.root.appending(path: "alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: documents)
        let viaAlias = try sandbox.run([sandbox.target(alias)])
        #expect(SystemLogs.failedPositions(in: viaAlias.stderr) == [0])
        #expect(Files.exists(precious))
    }

    /// Names are data. Whatever a folder is called, the script deletes inside it and runs none of it.
    @Test func namesThatLookLikeCommandsAreOnlyNames() throws {
        let sandbox = try LogSandbox()
        defer { sandbox.remove() }
        let names = ["it's", "say \"hi\"", "-rf", "a b  c", "$(touch pwned)", "`touch pwned`", "semi;touch pwned", "名前", "back\\slash", "*"]
        var old: [URL] = []
        for name in names {
            // Once as the folder root is pointed at, once as a folder met on the way down.
            old.append(try sandbox.file(sandbox.logs.appending(path: name).appending(path: "old.log"), age: 30))
            old.append(try sandbox.file(sandbox.logs.appending(path: "Nest").appending(path: name).appending(path: "old.log"), age: 30))
        }
        let before = sandbox.everything()

        let output = try sandbox.run(names.map { sandbox.target(sandbox.logs, $0) } + [sandbox.target(sandbox.logs, "Nest")])
        #expect(output.status == 0, "\(output.stderr)")
        let leftBehind = old.filter { Files.exists($0) }.map(\.lastPathComponent)
        #expect(leftBehind.isEmpty)
        // Nothing was made, anywhere: every path now there was there before.
        #expect(sandbox.everything().isSubset(of: before))
        #expect(!FileManager.default.fileExists(atPath: FileManager.default.currentDirectoryPath + "/pwned"))
    }

    @Test func theScriptSaysWhichFolderItCouldNotFinish() throws {
        let sandbox = try LogSandbox()
        defer { sandbox.remove() }
        let gone = try sandbox.file(sandbox.logs.appending(path: "Open/old.log"), age: 30)
        let alsoGone = try sandbox.file(sandbox.logs.appending(path: "Partly/old.log"), age: 30)
        let locked = sandbox.logs.appending(path: "Partly/locked")
        let kept = try sandbox.file(locked.appending(path: "old.log"), age: 30)
        // A folder nothing may be removed from stands in for one macOS keeps for itself.
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }

        let output = try sandbox.run([sandbox.target(sandbox.logs, "Open"), sandbox.target(sandbox.logs, "Partly")])
        #expect(output.status != 0)
        #expect(SystemLogs.failedPositions(in: output.stderr) == [1])
        #expect(!Files.exists(gone))
        #expect(!Files.exists(alsoGone))
        #expect(Files.exists(kept))
    }

    @Test func whatTheScriptWroteBeforeFailingIsReadBack() {
        #expect(SystemLogs.failedPositions(in: "failed: 0 3\n") == [0, 3])
        // The way osascript hands it on, with its own words around it.
        #expect(SystemLogs.failedPositions(in: "0:412: execution error: failed: 2 (1)") == [2])
        #expect(SystemLogs.failedPositions(in: "User canceled. (-128)").isEmpty)
        #expect(SystemLogs.failedPositions(in: "").isEmpty)
    }

    @Test func aPlanHandsAGroupsFoldersToRootTogether() throws {
        let sandbox = try LogSandbox()
        defer { sandbox.remove() }
        try sandbox.folder(sandbox.logs.appending(path: "CrashReporter"))
        let crashes = sandbox.target(sandbox.logs, "CrashReporter")
        let items = [
            FindingItem(id: "j/crashes", title: "CrashReporter", detail: "", size: 300, paths: [crashes.url], systemTarget: crashes),
            FindingItem(id: "j/loose", title: "Loose", detail: "", size: 200, paths: [sandbox.systemLog],
                        systemTarget: sandbox.target(sandbox.systemLog)),
            FindingItem(id: "j/unticked", title: "Unticked", detail: "", size: 100, paths: [sandbox.logs],
                        systemTarget: sandbox.target(sandbox.logs)),
        ]
        let logs = Finding(id: SystemLogs.findingID, area: .cachesLogs, aftermath: .rebuilds, title: "System logs",
                           summary: "", explanation: "", method: .adminDelete, actionTarget: "", items: items)
        let caches = Finding(id: "caches", area: .cachesLogs, aftermath: .rebuilds, title: "App caches", summary: "", explanation: "",
                             method: .delete, actionTarget: "", items: [FindingItem(id: "c/1", title: "", detail: "", size: 50,
                                                                                    paths: [sandbox.root.appending(path: "x")])])
        let plan = CleanPlan.make(findings: [caches, logs], selection: ["c/1", "j/crashes", "j/loose"])
        #expect(plan.steps.map(\.id) == ["caches", SystemLogs.findingID])
        let step = try #require(plan.steps.last)
        #expect(step.method == .adminDelete)
        #expect(step.fate == .deletedAsRoot)
        #expect(step.size == 500)
        #expect(step.operations.map(\.itemID) == ["j/crashes", "j/loose"])
        #expect(step.summary == "Delete old logs in 2 places, with your password")
        // One step, so one prompt, however many folders it names.
        #expect(plan.needsPassword)
        #expect(plan.passwordPromptCount == 1)
        #expect(plan.passwordPromptTimes == "once")
        #expect(plan.finalSize == 550)
        #expect(plan.withoutPasswordSteps.steps.map(\.id) == ["caches"])

        // The script someone copies is the one the app would hand to root: one line, both folders.
        let script = plan.shellScript()
        let rootLines = script.split(separator: "\n").filter { $0.hasPrefix("sudo ") }
        #expect(rootLines.count == 1)
        #expect(rootLines.first?.hasPrefix("sudo '/bin/sh' '-c' ") == true)
        #expect(script.contains(crashes.path))
        #expect(script.contains("/bin/pwd -P"))
    }

    /// A folder outside the ones that were looked at never reaches root, and nothing is asked for.
    @Test func theCleanerRefusesAFolderRootMayNotReachInto() throws {
        let sandbox = try LogSandbox()
        defer { sandbox.remove() }
        let documents = try sandbox.folder(sandbox.root.appending(path: "Users/someone/Documents"))
        let precious = try sandbox.file(documents.appending(path: "thesis.txt"), age: 400)
        let outside = SystemLogs.Target(root: documents.deletingLastPathComponent(), folder: "Documents")
        let step = CleanStep(
            id: SystemLogs.findingID, title: "System logs", aftermath: .rebuilds, method: .adminDelete, summary: "", size: 100,
            operations: [CleanOperation(itemID: "j/1", kind: .deleteAsAdmin(outside), size: 100)]
        )
        var log: [String] = []
        let outcome = Cleaner.deleteAsAdmin(step, roots: sandbox.roots, log: &log)
        #expect(outcome.cleanedItemIDs.isEmpty)
        #expect(outcome.failures.count == 1)
        #expect(outcome.failures.first?.contains("Refused") == true)
        #expect(outcome.fate == .deletedAsRoot)
        #expect(Files.exists(precious))

        // One at a time is refused as well: a group's folders only ever go to root together.
        let alone = Cleaner.perform(step.operations[0], safety: SafetyGuard(root: sandbox.root))
        #expect(alone.failure != nil)
    }
}
