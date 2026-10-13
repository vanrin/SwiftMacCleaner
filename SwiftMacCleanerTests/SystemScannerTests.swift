//
//  SystemScannerTests.swift
//  SwiftMacCleanerTests
//

import Foundation
import Testing
@testable import SwiftMacCleaner

/// A throwaway folder that stands in for a home directory.
private struct Sandbox {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "mdc-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    @discardableResult
    func file(_ path: String, bytes: Int = 16, age days: Double = 0) throws -> URL {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 7, count: bytes).write(to: url)
        try setAge(days, of: url)
        return url
    }

    func setAge(_ days: Double, of url: URL) throws {
        let date = Date().addingTimeInterval(-days * 86_400)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }
}

struct SnapshotScannerTests {
    @Test func readsSnapshotDatesAndIgnoresTheHeader() throws {
        let output = """
        Snapshots for disk /:
        com.apple.TimeMachine.2026-10-06-120000.local
        com.apple.TimeMachine.2026-10-07-083000.local
        """
        let dates = SnapshotScanner.snapshotDates(from: output)
        #expect(dates.count == 2)
        let calendar = Calendar.current
        let first = try #require(dates.first)
        #expect(calendar.component(.day, from: first) == 6)
        #expect(calendar.component(.hour, from: first) == 12)
        #expect(SnapshotScanner.snapshotDates(from: "Snapshots for disk /:\n").isEmpty)
    }

    @Test func namesABackupByItsDevice() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let backup = "Library/Application Support/MobileSync/Backup/00008030-ABCDEF"
        try sandbox.file("\(backup)/Manifest.db", bytes: 60_000_000)
        let info: [String: Any] = ["Device Name": "Vanrin's iPhone", "Product Name": "iPhone 17 Pro",
                                   "Last Backup Date": Date().addingTimeInterval(-400 * 86_400)]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: sandbox.root.appending(path: "\(backup)/Info.plist"))

        let result = await SnapshotScanner.scan(ScanContext(home: sandbox.root, excluded: [SnapshotScanner.snapshotsItemID]))
        let finding = try #require(result.findings.first { $0.id == "snapshots.backups" })
        #expect(finding.aftermath == .irreplaceable)
        #expect(finding.method == .trash)
        #expect(finding.items.map(\.title) == ["Vanrin's iPhone"])
        #expect(finding.items.first?.detail.hasPrefix("Backed up") == true)
    }
}

struct HomebrewCleanupTests {
    @Test func readsTheSizeBrewWouldFree() {
        let output = """
        Would remove: /Users/me/Library/Logs/Homebrew/axe (6 files, 1.5KB)
        Would remove: /opt/homebrew/Library/Homebrew/vendor/portable-ruby/4.0.6 (1,707 files, 34.6MB)
        ==> This operation would free approximately 2.4GB of disk space.
        """
        #expect(PackageCacheScanner.bytes(fromCleanupOutput: output) == 2_400_000_000)
        #expect(PackageCacheScanner.bytes(fromCleanupOutput: "==> This operation would free approximately 34.6MB of disk space.") == 34_600_000)
        #expect(PackageCacheScanner.bytes(fromCleanupOutput: "Nothing to clean up.\n") == 0)
        #expect(PackageCacheScanner.bytes(fromCleanupOutput: "") == 0)
    }
}

struct LeftoverScannerTests {
    @Test func tellsBundleIdentifiersFromPlainFolderNames() {
        #expect(LeftoverScanner.looksLikeBundleID("com.bohemiancoding.sketch3"))
        #expect(LeftoverScanner.looksLikeBundleID("us.zoom.xos"))
        #expect(!LeftoverScanner.looksLikeBundleID("Google"))
        #expect(!LeftoverScanner.looksLikeBundleID("com.x"))
        #expect(!LeftoverScanner.looksLikeBundleID("JetBrains"))
        #expect(!LeftoverScanner.looksLikeBundleID("my.app name"))
    }

    @Test func anInstalledAppClaimsItsHelpers() {
        let installed: Set<String> = ["com.figma.Desktop", "com.microsoft.VSCode"]
        #expect(LeftoverScanner.isOrphan(id: "com.bohemiancoding.sketch3", installed: installed))
        #expect(!LeftoverScanner.isOrphan(id: "com.figma.Desktop", installed: installed))
        #expect(!LeftoverScanner.isOrphan(id: "com.microsoft.VSCode.ShipIt", installed: installed))
        #expect(LeftoverScanner.isOrphan(id: "com.microsoft.VSCodeInsiders", installed: installed))
    }

    @Test func offersOnlyFoldersOfAppsThatAreGoneAndIdle() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        // Gone and untouched: offered, with its preferences file.
        try sandbox.file("Library/Application Support/com.example.gone/data.bin", bytes: 11_000_000, age: 90)
        try sandbox.setAge(90, of: sandbox.root.appending(path: "Library/Application Support/com.example.gone"))
        try sandbox.file("Library/Preferences/com.example.gone.plist", age: 90)
        // Gone but written to this week: protected.
        try sandbox.file("Library/Caches/com.example.busy/blob.bin", bytes: 11_000_000, age: 2)
        // Finder is always installed and running.
        try sandbox.file("Library/Caches/com.apple.finder/blob.bin", bytes: 11_000_000, age: 90)
        // Not a bundle identifier.
        try sandbox.file("Library/Application Support/Code/blob.bin", bytes: 11_000_000, age: 90)

        let result = await LeftoverScanner.scan(ScanContext(home: sandbox.root))
        let finding = try #require(result.findings.first)
        #expect(finding.items.map(\.hint) == ["com.example.gone"])
        #expect(finding.items.first?.paths.map(\.lastPathComponent).sorted() == ["com.example.gone", "com.example.gone.plist"])
        #expect(finding.items.first?.preselected == false)
        #expect(result.protected.map(\.title) == ["busy"])
        #expect(result.protected.first?.rule == .recentlyUsed)
    }
}

struct ContainerCachesTests {
    @Test func offersCachesInsideAppContainersButNotApplesOwn() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.file("Library/Containers/com.example.notes/Data/Library/Caches/blob.bin", bytes: 11_000_000)
        try sandbox.file("Library/Containers/com.example.notes/Data/Documents/keep.txt")
        try sandbox.file("Library/Containers/com.apple.Safari/Data/Library/Caches/blob.bin", bytes: 11_000_000)
        try sandbox.file("Library/Containers/com.example.tiny/Data/Library/Caches/blob.bin", bytes: 1_000)

        let result = await CachesLogsScanner.scan(ScanContext(home: sandbox.root))
        let finding = try #require(result.findings.first { $0.id == "caches.containers" })
        #expect(finding.items.map(\.title) == ["notes"])
        #expect(finding.items.first?.paths.first?.path.hasSuffix("com.example.notes/Data/Library/Caches") == true)
    }
}

struct AccessProbeTests {
    @Test func aMissingProbeIsPassedOverRatherThanReadAsRefused() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let folder = try sandbox.file("Library/Safari/Bookmarks.plist").deletingLastPathComponent()
        let gone = sandbox.root.appending(path: "Library/Application Support/com.apple.TCC/TCC.db")

        #expect(Files.firstPresentOpens([gone, folder]))
        #expect(!Files.firstPresentOpens([gone]))
    }

    @Test func aProbeThatIsThereButRefusedSettlesIt() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let locked = try sandbox.file("Library/Mail/Envelope Index")
        let open = try sandbox.file("Library/Safari/Bookmarks.plist")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)

        #expect(!Files.firstPresentOpens([locked, open]))
    }
}
