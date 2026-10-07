//
//  SafetyCoreTests.swift
//  Mac Disk CleanerTests
//
//  The ten safety rules, one test each where a test can reach them.
//

import Foundation
import Testing
@testable import Mac_Disk_Cleaner

/// A throwaway folder that stands in for a home directory.
private struct Sandbox {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "mdc-core-\(UUID().uuidString)")
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

private func finding(id: String = "f", area: Area = .packageCaches, tier: SafetyTier = .safe,
                     method: CleanMethod = .delete, items: [FindingItem]) -> Finding {
    Finding(id: id, area: area, tier: tier, title: id, summary: "", explanation: "",
            method: method, actionTarget: "", items: items)
}

struct CatalogTests {
    /// Rule 1: every entry in the catalog is somewhere the guard would let the cleaner touch.
    @Test func everyKnownLocationPassesTheGuard() {
        let home = URL(fileURLWithPath: "/Users/someone", isDirectory: true)
        let safety = SafetyGuard(root: home)
        for group in Catalog.allGroups {
            for location in group.locations {
                let url = home.appending(path: location.path)
                #expect(safety.allows(url), "\(group.id): \(location.path) would be refused")
                #expect(!location.path.hasPrefix("/"), "\(location.path) must be relative to home")
            }
        }
    }

    @Test func groupsHaveDistinctIDsAndSensibleMethods() {
        let ids = Catalog.allGroups.map(\.id)
        #expect(Set(ids).count == ids.count)
        for group in Catalog.allGroups {
            #expect(group.method == .delete || group.method == .trash, "\(group.id) is a folder group")
            #expect(group.tier != .careful || group.method == .trash, "careful groups must go to the Trash")
        }
    }

    @Test func cachesClaimedByAGroupAreLeftToIt() {
        #expect(Catalog.claimedCacheFolders.contains("Homebrew"))
        #expect(Catalog.claimedCacheFolders.contains("pip"))
        #expect(!Catalog.claimedCacheFolders.contains("com.google.Chrome"))
    }
}

struct GuardRulesTests {
    /// Rule 3: the protected list, by prefix, by component and by extension.
    @Test func refusesTheProtectedList() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let safety = SafetyGuard(root: sandbox.root)
        let refused = [
            "Library/Mobile Documents/com~apple~CloudDocs/Notes/x",
            "Library/CloudStorage/Dropbox/x",
            "Library/Mail/V10/x",
            "Library/Keychains/login.keychain-db",
            "Library/Application Support/MobileSync/Backup/ABC",
            "Code/app/.git/objects",
            "Code/app/node_modules/.git",
            "Pictures/Photos Library.photoslibrary/originals",
            ".ssh/id_ed25519",
        ]
        let allowed = refused.filter { safety.refusal(for: sandbox.root.appending(path: $0)) == nil }
        #expect(allowed.isEmpty, "these should have been refused: \(allowed)")
        #expect(safety.allows(sandbox.root.appending(path: "Code/app/node_modules")))
        #expect(safety.allows(sandbox.root.appending(path: "Library/Containers/com.foo.app/Data/Library/Caches")))
    }

    @Test func backupsAreOnlyReachableAsWholeBackupsWhenAllowed() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let backup = sandbox.root.appending(path: "Library/Application Support/MobileSync/Backup/00008030-ABC")
        #expect(!SafetyGuard(root: sandbox.root).allows(backup))
        var safety = SafetyGuard(root: sandbox.root)
        safety.backupsAllowed = true
        #expect(safety.allows(backup))
        #expect(!safety.allows(backup.appending(path: "Manifest.db")))
        #expect(!safety.allows(backup.deletingLastPathComponent()))
    }

    /// Rule 2: extra roots allow their children, applications only as whole bundles.
    @Test func allowsExtraRootsAndNamedApplicationsOnly() throws {
        let sandbox = try Sandbox()
        let temp = try Sandbox()
        defer { sandbox.remove(); temp.remove() }
        let oldXcode = URL(fileURLWithPath: "/Applications/Xcode-16.4.app")
        let safety = SafetyGuard(root: sandbox.root, extraRoots: [temp.root], allowedApplications: [oldXcode])

        #expect(safety.allows(temp.root.appending(path: "com.foo.cache")))
        #expect(!safety.allows(temp.root))
        #expect(safety.allows(oldXcode))
        #expect(!safety.allows(URL(fileURLWithPath: "/Applications/Xcode.app")))
        #expect(!safety.allows(oldXcode.appending(path: "Contents")))
    }

    /// Rule 8: the Never Suggest list wins over everything, even for a path that would otherwise pass.
    @Test func refusesTheNeverSuggestList() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let models = sandbox.root.appending(path: ".ollama/models")
        let safety = SafetyGuard(root: sandbox.root, neverSuggest: [models.path])
        #expect(safety.refusal(for: models) == "on your Never Suggest list")
        #expect(safety.refusal(for: models.appending(path: "blobs")) == "on your Never Suggest list")
        #expect(safety.allows(sandbox.root.appending(path: ".ollama/logs")))
    }
}

struct FreshnessTests {
    /// Rule 4: anything changed after the scan is skipped and reported, not removed.
    @Test func skipsAFolderThatChangedAfterTheScan() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let stale = try sandbox.file(".npm/_cacache/old.bin", age: 3).deletingLastPathComponent()
        try sandbox.setAge(3, of: stale)
        let fresh = try sandbox.file(".npm/_npx/new.bin", age: 3).deletingLastPathComponent()
        try sandbox.setAge(3, of: fresh)
        let scannedAt = Date().addingTimeInterval(-60)
        // A build writes into the folder after the scan.
        try sandbox.file(".npm/_npx/written-later.bin")

        let plan = CleanPlan.make(findings: [finding(items: [
            FindingItem(id: "f/stale", title: "stale", detail: "", size: 10, paths: [stale]),
            FindingItem(id: "f/fresh", title: "fresh", detail: "", size: 10, paths: [fresh]),
        ])], selection: ["f/stale", "f/fresh"])
        let outcome = await Cleaner.run(plan: plan, safety: SafetyGuard(root: sandbox.root), scannedAt: scannedAt) { _ in }

        #expect(outcome.cleanedItemIDs == ["f/stale"])
        #expect(!Files.exists(stale))
        #expect(Files.exists(fresh))
        #expect(outcome.steps.first?.skippedItems["f/fresh"]?.contains("changed since the scan") == true)
        #expect(outcome.failureCount == 0)
    }

    @Test func newestChangeLooksOneLevelDown() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let folder = try sandbox.file("cache/a.bin", age: 10).deletingLastPathComponent()
        try sandbox.setAge(10, of: folder)
        let old = try #require(Cleaner.newestChange(in: folder))
        #expect(old < Date().addingTimeInterval(-9 * 86_400))
        try sandbox.file("cache/b.bin")
        try sandbox.setAge(10, of: folder)
        let newest = try #require(Cleaner.newestChange(in: folder))
        #expect(newest > Date().addingTimeInterval(-60))
    }
}

struct PutBackTests {
    /// Rule 6: Trash first, and everything can come back until the Trash is emptied.
    @Test func trashedItemsAreRecordedAndCanBePutBack() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let installer = try sandbox.file("Downloads/Tool.dmg", bytes: 1000)
        let item = FindingItem(id: "f/dmg", title: "Tool.dmg", detail: "", size: 1000, paths: [installer])
        let plan = CleanPlan.make(findings: [finding(tier: .review, method: .trash, items: [item])], selection: ["f/dmg"])

        let outcome = await Cleaner.run(plan: plan, safety: SafetyGuard(root: sandbox.root)) { _ in }
        let trashed = try #require(outcome.trashed.first)
        #expect(trashed.original == installer)
        #expect(trashed.size == 1000)
        #expect(outcome.trashedSize == 1000)
        #expect(!Files.exists(installer))
        #expect(Files.exists(trashed.inTrash))
        defer { try? FileManager.default.removeItem(at: trashed.inTrash) }

        PutBack.save(outcome, home: sandbox.root)
        let pending = try #require(PutBack.pending(home: sandbox.root))
        #expect(pending.items == [trashed])

        let failures = PutBack.restore(pending, home: sandbox.root)
        #expect(failures.isEmpty)
        #expect(Files.exists(installer))
        #expect(!Files.exists(trashed.inTrash))
        #expect(PutBack.pending(home: sandbox.root) == nil)
    }

    @Test func anEmptiedTrashLeavesNothingToPutBack() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let gone = TrashedItem(original: sandbox.root.appending(path: "Downloads/x.dmg"),
                               inTrash: sandbox.root.appending(path: ".Trash/x.dmg"), size: 5)
        let outcome = CleanOutcome(steps: [StepOutcome(id: "s", title: "s", method: .trash, size: 5, cleanedItemIDs: [],
                                                       failures: [], trashed: [gone])],
                                   freeBefore: 0, freeAfter: 0, trashedSize: 5, duration: 0, logURL: nil, started: Date())
        PutBack.save(outcome, home: sandbox.root)
        #expect(PutBack.pending(home: sandbox.root) == nil)
    }
}

struct PasswordStepTests {
    /// Rule 7: only an admin command asks for a password, and the script shows it as sudo.
    @Test func adminCommandsAreMarkedAndScriptedWithSudo() {
        let snapshots = finding(id: "snapshots.local", area: .snapshots, tier: .review, method: .adminCommand, items: [
            FindingItem(id: "snapshots.local", title: "3 local snapshots", detail: "", size: 0,
                        command: ["/usr/bin/tmutil", "deletelocalsnapshots", "/"], sizeUnknown: true),
        ])
        let caches = finding(items: [FindingItem(id: "f/npm", title: "", detail: "", size: 5, paths: [URL(fileURLWithPath: "/Users/me/.npm/_cacache")])])
        let plan = CleanPlan.make(findings: [caches, snapshots], selection: ["f/npm", "snapshots.local"])
        #expect(plan.needsPassword)
        #expect(plan.steps.last?.operations == [CleanOperation(itemID: "snapshots.local", kind: .runAsAdmin(["/usr/bin/tmutil", "deletelocalsnapshots", "/"]), size: 0)])
        #expect(plan.shellScript().contains("sudo '/usr/bin/tmutil' 'deletelocalsnapshots' '/'"))
        #expect(!CleanPlan.make(findings: [caches], selection: ["f/npm"]).needsPassword)
    }
}

struct NeverSuggestScanTests {
    /// Rule 8, scan side: an excluded item leaves the findings and shows up under Protected.
    @Test func excludedItemsMoveToTheProtectedList() {
        let home = URL(fileURLWithPath: "/Users/me")
        let models = home.appending(path: ".ollama/models")
        let result = AreaScanResult(findings: [finding(area: .models, tier: .review, items: [
            FindingItem(id: "m/ollama", title: "Ollama models", detail: "Models pulled with ollama", size: 12, paths: [models]),
            FindingItem(id: "m/hf", title: "Hugging Face", detail: "", size: 9, paths: [home.appending(path: ".cache/huggingface/hub")]),
        ])])
        var context = ScanContext(home: home)
        context.excluded = [models.path]

        let filtered = ScanEngine.applyingExclusions(to: result, context: context)
        #expect(filtered.findings.first?.items.map(\.id) == ["m/hf"])
        #expect(filtered.protected.map(\.rule) == [.neverSuggest])
        #expect(filtered.protected.first?.size == 12)

        // A finding whose every item is excluded disappears, and the context matches children too.
        context.excluded = [home.appending(path: ".cache").path, models.path]
        #expect(ScanEngine.applyingExclusions(to: result, context: context).findings.isEmpty)
    }
}

struct GuardRootsTests {
    @Test func findsThePerUserTempFoldersUnderVarFolders() {
        let folders = GuardRoots.userTemporaryFolders()
        #expect(folders.count == 2)
        for folder in folders {
            #expect(folder.path.hasPrefix("/var/folders/") || folder.path.hasPrefix("/private/var/folders/"))
            #expect(Files.isDirectory(folder))
        }
    }

    @Test func theSelectedXcodeIsNeverAmongTheOthers() {
        let selected = GuardRoots.selectedXcode()
        let others = GuardRoots.otherXcodes()
        #expect(selected.map { s in others.contains { $0.standardizedFileURL.path == s.standardizedFileURL.path } } != true)
    }
}

struct DiskInfoTests {
    @Test func usedSpaceLeavesOutWhatIsPurgeable() {
        let disk = DiskInfo(name: "Macintosh HD", capacity: 1000, free: 100, purgeable: 50)
        #expect(disk.used == 850)
        #expect(disk.isLow)
    }
}
