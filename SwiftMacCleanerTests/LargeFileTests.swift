//
//  LargeFileTests.swift
//  SwiftMacCleanerTests
//
//  Large old files in Downloads, Documents and Desktop: where the scan looks, what it passes over, and
//  how it tells a file nobody uses from one that only looks old.
//

import Foundation
import SwiftUI
import Testing
@testable import SwiftMacCleaner

/// A throwaway home folder whose files can be made to look as if they had sat there for months.
private struct Home {
    let root: URL
    /// Small enough to write quickly; the scans here are told that this counts as large.
    static let large: Int64 = 100_000

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "mdc-large-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    private func date(_ days: Double) -> Date { Date().addingTimeInterval(-days * 86_400) }

    /// A file last changed `age` days ago. It and the folders made for it look put there a year ago,
    /// unless `added` says when, and it was never opened unless `opened` says when.
    @discardableResult
    func file(_ path: String, bytes: Int = 200_000, age: Double = 200, added: Double = 365, opened: Double? = nil) throws -> URL {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 7, count: bytes).write(to: url)
        try settle(url, age: age, added: added)
        if let opened { setOpened(opened, of: url) }
        var folder = url.deletingLastPathComponent()
        while folder.path.count > root.path.count {
            try settle(folder, age: 365, added: 365)
            folder.deleteLastPathComponent()
        }
        return url
    }

    func settle(_ url: URL, age: Double, added: Double) throws {
        try FileManager.default.setAttributes([.modificationDate: date(age)], ofItemAtPath: url.path)
        try setAdded(added, of: url)
    }

    func setAdded(_ days: Double, of url: URL) throws {
        try (url as NSURL).setResourceValue(date(days), forKey: .addedToDirectoryDateKey)
    }

    /// Notes on the file that it was opened, the way macOS does when it is opened from Finder.
    func setOpened(_ days: Double, of url: URL) {
        var stamp = timespec(tv_sec: Int(date(days).timeIntervalSince1970), tv_nsec: 0)
        _ = setxattr(url.path, LargeFileScanner.lastOpenedAttribute, &stamp, MemoryLayout<timespec>.size, 0, 0)
    }

    func context(days: Int = 90, projectRoots: [String] = [], excluded: [String] = []) -> ScanContext {
        ScanContext(home: root, largeFileDays: days, largeFileSize: Self.large, projectRoots: projectRoots.map { root.appending(path: $0) },
                    excluded: excluded.map { root.appending(path: $0).standardizedFileURL.path })
    }

    func scan(days: Int = 90, projectRoots: [String] = [], excluded: [String] = [], openFiles: OpenFiles? = OpenFiles(),
              isRunning: @Sendable (URL) -> Bool = { _ in false },
              isInCloud: @Sendable (URL) -> Bool = { _ in false }) async -> AreaScanResult {
        await LargeFileScanner.scan(context(days: days, projectRoots: projectRoots, excluded: excluded), openFiles: openFiles,
                                    isInCloud: isInCloud, isRunning: isRunning)
    }
}

struct LargeFileScannerTests {
    @Test func offersBigOldFilesButNotInstallersOrFreshOnes() async throws {
        let sandbox = try Home()
        defer { sandbox.remove() }
        // The real limit, on files of the real size.
        try sandbox.file("Downloads/dataset.zip", bytes: 101_000_000)
        try sandbox.file("Downloads/nearly.zip", bytes: 99_000_000)
        try sandbox.file("Downloads/Installer.dmg", bytes: 6_000_000)

        let context = ScanContext(home: sandbox.root, largeFileDays: 90)
        let result = await LargeFileScanner.scan(context)
        #expect(result.findings.map(\.id) == ["largeFiles.downloads"])
        let large = try #require(result.findings.first)
        #expect(large.area == .largeFiles)
        #expect(large.aftermath == .irreplaceable)
        #expect(large.method == .trash)
        #expect(large.actionTarget == "~/Downloads")
        #expect(large.summary == "1 file of 100 MB or more untouched for 90+ days")
        #expect(large.items.map(\.title) == ["dataset.zip"])
        #expect(large.items.first?.id == "largeFiles.downloads/\(sandbox.root.path)/Downloads/dataset.zip")
        #expect(large.items.first?.detail.hasPrefix("Archive, last changed") == true)
        // Nothing here is ticked for the user.
        #expect(large.items.allSatisfy { $0.preselected == nil })
        // The installer is Applications' to offer, whatever its age.
        let installers = try #require(await InstallerScanner.scan(context).findings.first)
        #expect(installers.id == AppsModel.installersFindingID)
        #expect(installers.area == .installers)
        #expect(installers.items.map(\.title) == ["Installer.dmg"])
    }

    @Test func looksThroughDownloadsDocumentsAndDesktopToTheBottom() async throws {
        let sandbox = try Home()
        defer { sandbox.remove() }
        try sandbox.file("Downloads/survey.zip", bytes: 300_000)
        try sandbox.file("Downloads/Old/Setup.dmg")
        try sandbox.file("Downloads/Installer.dmg")
        try sandbox.file("Downloads/fresh.zip", age: 3, added: 3)
        try sandbox.file("Downloads/small.zip", bytes: 1_000)
        try sandbox.file("Documents/Recordings/2024/talk.mov", bytes: 400_000)
        try sandbox.file("Documents/ledger.numbers")
        try sandbox.file("Documents/.cache.bin")
        try sandbox.file("Documents/.hidden/big.bin")
        try sandbox.file("Desktop/build.apk")
        // Somewhere else in the home folder is somebody else's to look at.
        try sandbox.file("Movies/film.mov")

        let result = await sandbox.scan()
        #expect(result.findings.map(\.id) == ["largeFiles.downloads", "largeFiles.documents", "largeFiles.desktop"])
        #expect(result.findings.map(\.title) == ["Large files in Downloads", "Large files in Documents", "Large files on the Desktop"])
        #expect(result.findings.map(\.actionTarget) == ["~/Downloads", "~/Documents", "~/Desktop"])
        // The largest first. An installer further down in Downloads is nobody else's to offer.
        #expect(result.findings[0].items.map(\.title) == ["survey.zip", "Setup.dmg"])
        #expect(result.findings[1].items.map(\.title) == ["talk.mov", "ledger.numbers"])
        #expect(result.findings[2].items.map(\.title) == ["build.apk"])
        // A file further down says where.
        #expect(result.findings[1].items[0].detail.hasPrefix("Video in Recordings/2024, last changed") == true)
        #expect(result.findings[1].items[1].detail.hasPrefix("NUMBERS file, last changed") == true)
        #expect(result.findings[0].items[1].detail.hasPrefix("DMG file in Old, ") == true)
        #expect(result.findings[1].summary == "2 files of 100 KB or more untouched for 90+ days")
        #expect(result.findings.flatMap(\.items).allSatisfy { $0.paths.count == 1 && $0.size >= Home.large })
        // Whatever is offered is something the guard lets go.
        let guardian = SafetyGuard(root: sandbox.root)
        #expect(result.findings.flatMap(\.items).allSatisfy { guardian.allows($0.paths[0]) })
        #expect(result.protected.isEmpty)
        #expect(result.unreadable.isEmpty)
        #expect(result.skipReason == nil)
    }

    @Test func leavesProjectsPackagesAndProjectFoldersAlone() async throws {
        let sandbox = try Home()
        defer { sandbox.remove() }
        // A project with what it built, a repository, and what a package manager fills.
        try sandbox.file("Documents/site/package.json", bytes: 100)
        try sandbox.file("Documents/site/release/site-1.0.zip")
        try sandbox.file("Documents/data/.git/HEAD", bytes: 100)
        try sandbox.file("Documents/data/dump.sql")
        try sandbox.file("Documents/site/release/Site.app/Contents/Resources/model.bin")
        try sandbox.file("Documents/scratch/node_modules/pkg/blob.bin")
        // A folder named in Settings as one that holds projects, with a loose file in it.
        try sandbox.file("Documents/Work/handoff.zip")
        // A stray project file directly in Documents does not make Documents a project.
        try sandbox.file("Documents/package.json", bytes: 100)
        try sandbox.file("Documents/loose.mov")

        let named = await sandbox.scan(projectRoots: ["Documents/Work"])
        #expect(named.findings.map(\.id) == ["largeFiles.documents"])
        #expect(named.findings.first?.items.map(\.title) == ["loose.mov"])
        // Not named, the same folder is like any other.
        let unnamed = await sandbox.scan()
        #expect(unnamed.findings.first?.items.map(\.title).sorted() == ["handoff.zip", "loose.mov"])
    }

    @Test func goesByTheLatestOfChangedAddedAndOpened() async throws {
        let sandbox = try Home()
        defer { sandbox.remove() }
        try sandbox.file("Documents/changed.zip", age: 200, added: 300)
        // Unpacked this week from an old archive: the dates inside are the archive's.
        try sandbox.file("Documents/unpacked.zip", age: 700, added: 3)
        try sandbox.file("Documents/moved.zip", age: 700, added: 150)
        // Never written to, but watched last week.
        try sandbox.file("Documents/watched.mov", age: 700, opened: 6)
        try sandbox.file("Documents/forgotten.mov", age: 700, opened: 120)
        // A folder moved in yesterday leaves the files in it as they were.
        let inside = try sandbox.file("Documents/Brought/old.zip", age: 700)
        try sandbox.setAdded(1, of: inside.deletingLastPathComponent())
        // Changed since it was put there.
        try sandbox.file("Documents/edited.zip", age: 10, added: 300)

        let result = await sandbox.scan()
        let items = try #require(result.findings.first?.items)
        let details = Dictionary(uniqueKeysWithValues: items.map { ($0.title, $0.detail) })
        #expect(details.keys.sorted() == ["changed.zip", "forgotten.mov", "moved.zip"])
        #expect(details["changed.zip"]?.hasPrefix("Archive, last changed") == true)
        #expect(details["moved.zip"]?.hasPrefix("Archive, added") == true)
        #expect(details["forgotten.mov"]?.hasPrefix("Video, last opened") == true)

        // A longer limit takes the ones that are not old enough for it out.
        let patient = await sandbox.scan(days: 180)
        #expect(patient.findings.first?.items.map(\.title) == ["changed.zip"])
        let impatient = await sandbox.scan(days: 30)
        #expect(impatient.findings.first?.items.count == 3)
        #expect(impatient.findings.first?.summary.hasSuffix("untouched for 30+ days") == true)

        let candidate = LargeFileScanner.Candidate(path: inside.path, size: 200_704, modified: Date().addingTimeInterval(-700 * 86_400))
        let touch = LargeFileScanner.lastTouch(of: candidate, below: sandbox.root.appending(path: "Documents"))
        #expect(touch.kind == .added)
        #expect(abs(touch.date.timeIntervalSinceNow + 86_400) < 60)
        #expect(LargeFileScanner.lastOpened(inside.path) == nil)
    }

    @Test func leavesAloneWhatARunningProgramHasOpen() async throws {
        let sandbox = try Home()
        defer { sandbox.remove() }
        let held = try sandbox.file("Documents/Machines/disk.img", bytes: 300_000)
        try sandbox.file("Documents/idle.img")

        // This test is a running program of the user's, and it has the file open.
        let handle = try FileHandle(forReadingFrom: held)
        let result = await sandbox.scan(openFiles: nil)
        try handle.close()
        #expect(result.findings.first?.items.map(\.title) == ["idle.img"])
        #expect(result.protected.map(\.title) == ["disk.img"])
        let kept = try #require(result.protected.first)
        #expect(kept.rule == .inUse)
        #expect(kept.area == .largeFiles)
        #expect(kept.size == 303_104)
        #expect(kept.why.hasSuffix("/Documents/Machines. A running program has it open"))

        // Closed again, it is offered like the other.
        let later = await sandbox.scan(openFiles: nil)
        #expect(later.findings.first?.items.map(\.title) == ["disk.img", "idle.img"])
        #expect(later.protected.isEmpty)
    }

    @Test func leavesAloneWhatICloudKeeps() async throws {
        let sandbox = try Home()
        defer { sandbox.remove() }
        try sandbox.file("Downloads/synced/report.zip")
        try sandbox.file("Documents/archive.zip")
        try sandbox.file("Desktop/render.mov")

        // Desktop and Documents kept in iCloud, and a folder in Downloads some other service syncs.
        let result = await sandbox.scan { url in
            ["Documents", "Desktop"].contains(url.lastPathComponent) || url.path.contains("/synced/")
        }
        #expect(result.findings.isEmpty)
        #expect(result.protected.map(\.title) == ["Documents", "Desktop"])
        #expect(result.protected.allSatisfy { $0.rule == .protectedList && $0.size == nil && $0.why.contains("iCloud") })
        #expect(result.skipReason == "Documents and Desktop are kept in iCloud and left alone. Nothing large and old was found elsewhere.")
        #expect(result.unreadable.isEmpty)

        // With something to offer elsewhere there is nothing to explain.
        try sandbox.file("Downloads/dataset.zip")
        let mixed = await sandbox.scan { $0.lastPathComponent == "Documents" }
        #expect(mixed.findings.map(\.id) == ["largeFiles.downloads", "largeFiles.desktop"])
        #expect(mixed.protected.map(\.title) == ["Documents"])
        #expect(mixed.skipReason == nil)
    }

    @Test func saysWhenACopySharesItsDataAndPassesOverASecondName() async throws {
        let sandbox = try Home()
        defer { sandbox.remove() }
        let original = try sandbox.file("Documents/film.mov")
        // Finder's Duplicate: a second file pointing at the same data.
        let clone = sandbox.root.appending(path: "Documents/film copy.mov")
        try FileManager.default.copyItem(at: original, to: clone)
        try sandbox.settle(clone, age: 200, added: 365)
        try sandbox.file("Documents/alone.mov")
        // A second name for one file: taking one name away frees nothing.
        let named = try sandbox.file("Documents/ledger.numbers")
        try FileManager.default.linkItem(at: named, to: sandbox.root.appending(path: "Documents/ledger again.numbers"))

        let result = await sandbox.scan()
        let items = try #require(result.findings.first?.items)
        let details = Dictionary(uniqueKeysWithValues: items.map { ($0.title, $0.detail) })
        #expect(details.keys.sorted() == ["alone.mov", "film copy.mov", "film.mov"])
        // Where the disk makes clones, both say so; where it does not, neither does.
        let shares = FileStorage.read(original.path).map { $0.cloneCount > 1 } ?? false
        #expect(details["film.mov"]?.hasSuffix("A copy shares its data, so removing this one alone frees little") == shares)
        #expect(details["film copy.mov"]?.contains("A copy shares its data") == shares)
        #expect(details["alone.mov"]?.contains("shares") == false)
    }

    @Test func namesTheFoldersItCouldNotReadAndStillScansTheOthers() async throws {
        let sandbox = try Home()
        let locked: NSNumber = 0o000
        let open: NSNumber = 0o755
        let kept = ["Documents", "Desktop"].map { sandbox.root.appending(path: $0).path }
        defer {
            for path in kept { try? FileManager.default.setAttributes([.posixPermissions: open], ofItemAtPath: path) }
            sandbox.remove()
        }
        try sandbox.file("Downloads/dataset.zip")
        try sandbox.file("Documents/archive.zip")
        try sandbox.file("Desktop/render.mov")
        for path in kept { try FileManager.default.setAttributes([.posixPermissions: locked], ofItemAtPath: path) }

        let result = await sandbox.scan()
        #expect(result.findings.map(\.id) == ["largeFiles.downloads"])
        #expect(result.unreadable == ["Documents", "Desktop"])
        #expect(result.skipReason == nil)

        // With nothing found anywhere, the reason is the folders that stayed shut.
        try FileManager.default.removeItem(at: sandbox.root.appending(path: "Downloads/dataset.zip"))
        let empty = await sandbox.scan()
        #expect(empty.findings.isEmpty)
        #expect(empty.unreadable == ["Documents", "Desktop"])
        #expect(empty.skipReason?.hasPrefix("macOS did not let the app read Documents and Desktop.") == true)
    }

    @Test func aFolderThatIsMissingOrALinkIsPassedOver() async throws {
        let sandbox = try Home()
        defer { sandbox.remove() }
        // Desktop is a link to a folder somewhere else; Documents is not there at all.
        try sandbox.file("Elsewhere/render.mov")
        try FileManager.default.createSymbolicLink(at: sandbox.root.appending(path: "Desktop"),
                                                   withDestinationURL: sandbox.root.appending(path: "Elsewhere"))
        // A link inside a folder is not followed either.
        try sandbox.file("Downloads/dataset.zip")
        try FileManager.default.createSymbolicLink(at: sandbox.root.appending(path: "Downloads/shortcut"),
                                                   withDestinationURL: sandbox.root.appending(path: "Elsewhere"))

        let result = await sandbox.scan()
        #expect(result.findings.map(\.id) == ["largeFiles.downloads"])
        #expect(result.findings.first?.items.map(\.title) == ["dataset.zip"])
        #expect(result.unreadable.isEmpty)
        #expect(result.skipReason == nil)
    }

    @Test func offersAPackageWholeAndNeverPicksItApart() async throws {
        let sandbox = try Home()
        defer { sandbox.remove() }
        // An app left in Downloads: no one file in it is large, but all of it is.
        for part in ["Contents/MacOS/Tool", "Contents/Resources/a.car", "Contents/Resources/b.car"] {
            try sandbox.file("Downloads/Old Tool.app/\(part)", bytes: 60_000)
        }
        // A document that is a folder underneath, with one large picture in it.
        try sandbox.file("Documents/Notes.rtfd/TXT.rtf", bytes: 1_000)
        try sandbox.file("Documents/Notes.rtfd/scan.tiff", bytes: 250_000)
        // Something in this one changed last week.
        try sandbox.file("Documents/Busy.app/Contents/Resources/old.car", bytes: 150_000)
        try sandbox.file("Documents/Busy.app/Contents/Resources/new.car", bytes: 150_000, age: 5)
        // Too small even when added up.
        try sandbox.file("Documents/Tiny.app/Contents/MacOS/Tiny", bytes: 20_000)
        // A library macOS manages is never offered, and neither is anything in it.
        try sandbox.file("Documents/Photos Library.photoslibrary/originals/0/film.mov", bytes: 400_000)

        let result = await sandbox.scan()
        #expect(result.findings.map(\.id) == ["largeFiles.downloads", "largeFiles.documents"])
        let app = try #require(result.findings[0].items.first)
        #expect(result.findings[0].items.count == 1)
        #expect(app.title == "Old Tool.app")
        #expect(app.detail.hasPrefix("App, last changed") == true)
        #expect(app.paths == [sandbox.root.appending(path: "Downloads/Old Tool.app", directoryHint: .isDirectory)])
        // What all of it takes up, each file once.
        #expect(app.size >= 180_000 && app.size < 220_000)
        let notes = try #require(result.findings[1].items.first)
        #expect(result.findings[1].items.map(\.title) == ["Notes.rtfd"])
        #expect(notes.detail.hasPrefix("RTFD package, last changed") == true)
        #expect(notes.size >= 251_000)
        let guardian = SafetyGuard(root: sandbox.root)
        #expect(result.findings.flatMap(\.items).allSatisfy { guardian.allows($0.paths[0]) })

        // The app is open, or a program has something in the document open: both are left alone and said to be.
        let handle = try FileHandle(forReadingFrom: sandbox.root.appending(path: "Documents/Notes.rtfd/scan.tiff"))
        let busy = await sandbox.scan(openFiles: nil, isRunning: { $0.lastPathComponent == "Old Tool.app" })
        try handle.close()
        #expect(busy.findings.isEmpty)
        #expect(busy.protected.map(\.title) == ["Old Tool.app", "Notes.rtfd"])
        #expect(busy.protected.allSatisfy { $0.rule == .inUse })
        #expect(busy.protected.first?.why.hasSuffix("/Downloads. It is open") == true)
        #expect(busy.protected.last?.why.hasSuffix("/Documents. A running program has it open") == true)
        #expect(busy.protected.first?.size == app.size)

        // Opened last week, the app is not old, whatever the dates inside it say.
        sandbox.setOpened(6, of: sandbox.root.appending(path: "Downloads/Old Tool.app"))
        let opened = await sandbox.scan()
        #expect(opened.findings.map(\.id) == ["largeFiles.documents"])
        #expect(LargeFileScanner.isRunning(URL(fileURLWithPath: "/Applications/No Such App.app")) == false)
    }

    @Test func aPackageThatCannotBeReadIsPassedOverAndNothingElseWithIt() async throws {
        let sandbox = try Home()
        let locked: NSNumber = 0o000
        let open: NSNumber = 0o755
        let shut = ["Downloads/Locked.app", "Documents/Half.app/Contents/Private"].map { sandbox.root.appending(path: $0).path }
        defer {
            for path in shut { try? FileManager.default.setAttributes([.posixPermissions: open], ofItemAtPath: path) }
            sandbox.remove()
        }
        // One package that cannot be opened at all, among files that are found in no particular order.
        try sandbox.file("Downloads/Locked.app/Contents/MacOS/Tool")
        let names = (1...12).map { "export-\($0).zip" }
        for name in names { try sandbox.file("Downloads/\(name)") }
        // One with a part that cannot be read: it cannot be measured whole, so it is not offered.
        try sandbox.file("Documents/Half.app/Contents/MacOS/Tool")
        try sandbox.file("Documents/Half.app/Contents/Private/data.bin")
        try sandbox.file("Documents/whole.mov")
        for path in shut { try FileManager.default.setAttributes([.posixPermissions: locked], ofItemAtPath: path) }

        let result = await sandbox.scan()
        #expect(result.findings.map(\.id) == ["largeFiles.downloads", "largeFiles.documents"])
        #expect(result.findings[0].items.map(\.title).sorted() == names.sorted())
        #expect(result.findings[1].items.map(\.title) == ["whole.mov"])
        #expect(result.unreadable.isEmpty)
    }

    @Test func aFolderOnTheNeverSuggestListIsNotLookedInto() async throws {
        let sandbox = try Home()
        let locked: NSNumber = 0o000
        let open: NSNumber = 0o755
        let desktop = sandbox.root.appending(path: "Desktop").path
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: open], ofItemAtPath: desktop)
            sandbox.remove()
        }
        try sandbox.file("Documents/Archive/2023/ledger.zip")
        try sandbox.file("Documents/Archive/film.mov")
        try sandbox.file("Documents/loose.mov")
        try sandbox.file("Desktop/render.mov")
        // Shut, so that opening it would show: a folder on the list is passed over before that.
        try FileManager.default.setAttributes([.posixPermissions: locked], ofItemAtPath: desktop)

        let result = await sandbox.scan(excluded: ["Documents/Archive", "Desktop"])
        #expect(result.findings.map(\.id) == ["largeFiles.documents"])
        #expect(result.findings.first?.items.map(\.title) == ["loose.mov"])
        #expect(result.unreadable.isEmpty)
        #expect(result.protected.map(\.title) == ["Archive", "Desktop"])
        #expect(result.protected.allSatisfy { $0.rule == .neverSuggest && $0.size == nil })
        #expect(result.protected.first?.why == "~/Documents/Archive, with everything in it. On your Never Suggest list")
        #expect(result.protected.last?.why == "~/Desktop, with everything in it. On your Never Suggest list")
    }

    @MainActor @Test func theLimitsComeFromSettings() async throws {
        let sandbox = try Home()
        defer { sandbox.remove() }
        try sandbox.file("Downloads/big.zip", bytes: 600_000)
        try sandbox.file("Downloads/medium.zip", bytes: 200_000)

        var context = sandbox.context()
        #expect(await LargeFileScanner.scan(context, openFiles: OpenFiles()).findings.first?.items.count == 2)
        context.largeFileSize = 500_000
        let fewer = await LargeFileScanner.scan(context, openFiles: OpenFiles())
        #expect(fewer.findings.first?.items.map(\.title) == ["big.zip"])
        #expect(fewer.findings.first?.summary == "1 file of 500 KB or more untouched for 90+ days")
        // Unless Settings says otherwise, large is 100 MB.
        #expect(ScanContext(home: sandbox.root).largeFileSize == 100_000_000)

        let name = "mdc-large-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        #expect(settings.largeFileMegabytes == 100)
        #expect(settings.scanContext(home: sandbox.root).largeFileSize == 100_000_000)
        settings.largeFileMegabytes = 1_000
        settings.largeFileDays = 365
        let stored = AppSettings(defaults: defaults).scanContext(home: sandbox.root)
        #expect(stored.largeFileSize == 1_000_000_000)
        #expect(stored.largeFileDays == 365)
        // A size the picker does not offer is not taken from the defaults.
        defaults.set(7, forKey: "largeFileMegabytes")
        #expect(AppSettings(defaults: defaults).largeFileMegabytes == 100)
    }

    @Test func whatIsOfferedGoesToTheTrashAndCanBePutBack() async throws {
        let sandbox = try Home()
        defer { sandbox.remove() }
        let film = try sandbox.file("Documents/Recordings/film.mov")
        try sandbox.file("Documents/kept.mov")
        try sandbox.file("Desktop/Old Tool.app/Contents/MacOS/Tool")
        let app = sandbox.root.appending(path: "Desktop/Old Tool.app", directoryHint: .isDirectory)

        let scanned = Date()
        let result = await sandbox.scan()
        let chosen = result.findings.flatMap(\.items).filter { ["film.mov", "Old Tool.app"].contains($0.title) }
        #expect(chosen.count == 2)
        let plan = CleanPlan.make(findings: result.findings, selection: Set(chosen.map(\.id)))
        let outcome = await Cleaner.run(plan: plan, safety: SafetyGuard(root: sandbox.root), scannedAt: scanned) { _ in }
        defer { for item in outcome.trashed { try? FileManager.default.removeItem(at: item.inTrash) } }
        #expect(outcome.failureCount == 0)
        #expect(outcome.steps.allSatisfy { $0.succeeded })
        #expect(outcome.cleanedItemIDs == Set(chosen.map(\.id)))
        #expect(outcome.trashed.map(\.original.lastPathComponent).sorted() == ["Old Tool.app", "film.mov"])
        #expect(!Files.exists(film))
        #expect(!Files.exists(app))
        #expect(Files.exists(sandbox.root.appending(path: "Documents/kept.mov")))

        PutBack.save(outcome, home: sandbox.root)
        let pending = try #require(PutBack.pending(home: sandbox.root))
        #expect(PutBack.restore(pending, home: sandbox.root).isEmpty)
        #expect(Files.exists(film))
        #expect(Files.exists(app.appending(path: "Contents/MacOS/Tool")))
    }

    @MainActor @Test func aRowCanTakeItsWholeFolderOffTheList() async throws {
        let sandbox = try Home()
        let name = "mdc-large-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer {
            defaults.removePersistentDomain(forName: name)
            sandbox.remove()
        }
        try sandbox.file("Documents/Archive/2023/ledger.zip")
        try sandbox.file("Documents/Archive/film.mov", bytes: 300_000)
        try sandbox.file("Documents/loose.mov")
        try sandbox.file("Desktop/render.mov")
        let settings = AppSettings(defaults: defaults)
        let cleanUp = CleanUpModel(home: sandbox.root, settings: settings, group: .largeFiles)
        let result = await sandbox.scan()
        cleanUp.show(findings: result.findings)
        let documents = try #require(cleanUp.findings.first { $0.id == "largeFiles.documents" })
        let film = try #require(documents.items.first { $0.title == "film.mov" })
        for item in documents.items { cleanUp.binding(for: item).wrappedValue = true }
        #expect(cleanUp.selection.count == 3)

        cleanUp.neverSuggest(folderOf: film, in: documents)
        let archive = sandbox.root.appending(path: "Documents/Archive").standardizedFileURL.path
        #expect(settings.neverSuggest.map(\.path) == [archive])
        #expect(settings.neverSuggest.first?.title == "Archive")
        // Everything under the folder is gone from the list, the file two levels down too; the rest stays.
        #expect(cleanUp.findings.map(\.id) == ["largeFiles.documents", "largeFiles.desktop"])
        #expect(cleanUp.findings.first?.items.map(\.title) == ["loose.mov"])
        #expect(cleanUp.selection.count == 1)
        #expect(cleanUp.protected.first?.title == "Archive")
        #expect(cleanUp.protected.first?.rule == .neverSuggest)

        // The next scan says the same, without opening the folder.
        let again = await LargeFileScanner.scan(sandbox.context(excluded: ["Documents/Archive"]), openFiles: OpenFiles(),
                                                isInCloud: { _ in false })
        #expect(again.findings.first { $0.id == "largeFiles.documents" }?.items.map(\.title) == ["loose.mov"])
        #expect(again.protected == [try #require(cleanUp.protected.first)])
    }

    @Test func writesAListTheWayASentenceWould() {
        #expect(ListFormat.string([]) == "")
        #expect(ListFormat.string(["Documents"]) == "Documents")
        #expect(ListFormat.string(["Documents", "Desktop"]) == "Documents and Desktop")
        #expect(ListFormat.string(LargeFileScanner.folders.map(\.name)) == "Downloads, Documents and Desktop")
        #expect(ListFormat.string(LargeFileScanner.folders.map(\.name)) == AreaGroup.largeFiles.scope)
        #expect(LargeFileScanner.kind(of: URL(fileURLWithPath: "/a/b.MOV")) == "Video")
        #expect(LargeFileScanner.kind(of: URL(fileURLWithPath: "/a/backup")) == "File")
        #expect(LargeFileScanner.kind(of: URL(fileURLWithPath: "/a/disk.qcow2")) == "QCOW2 file")
        #expect(LargeFileScanner.kind(of: URL(fileURLWithPath: "/a/Windows 11.pvm"), isPackage: true) == "Virtual machine")
        #expect(LargeFileScanner.kind(of: URL(fileURLWithPath: "/a/Deck.key"), isPackage: true) == "KEY package")
    }
}
