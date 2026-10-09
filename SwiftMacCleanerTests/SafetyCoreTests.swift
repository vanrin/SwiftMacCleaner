//
//  SafetyCoreTests.swift
//  SwiftMacCleanerTests
//
//  The ten safety rules, one test each where a test can reach them.
//

import Foundation
import SwiftUI
import Testing
@testable import SwiftMacCleaner

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
            #expect(group.tier == .safe || group.method == .trash, "Review and Careful groups must go to the Trash")
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

    /// An item with several paths is left whole when any one of them changed.
    @Test func skipsTheWholeItemWhenOneOfItsPathsChanged() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let support = try sandbox.file("Library/Application Support/com.x.app/db.sqlite", age: 3).deletingLastPathComponent()
        let caches = try sandbox.file("Library/Caches/com.x.app/blob.bin", age: 3).deletingLastPathComponent()
        try sandbox.setAge(3, of: support)
        try sandbox.setAge(3, of: caches)
        let scannedAt = Date().addingTimeInterval(-60)
        try sandbox.file("Library/Application Support/com.x.app/new.sqlite")

        let plan = CleanPlan.make(findings: [finding(tier: .review, method: .trash, items: [
            FindingItem(id: "l/app", title: "app", detail: "", size: 10, paths: [support, caches]),
        ])], selection: ["l/app"])
        let outcome = await Cleaner.run(plan: plan, safety: SafetyGuard(root: sandbox.root), scannedAt: scannedAt) { _ in }
        #expect(outcome.cleanedItemIDs.isEmpty)
        #expect(Files.exists(support))
        #expect(Files.exists(caches))
        #expect(outcome.trashed.isEmpty)
    }

    @Test func newestChangeSeesDeepWrites() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let folder = try sandbox.file("T/com.x.word/a/b/c/old.bin", age: 10).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        for path in ["T/com.x.word", "T/com.x.word/a", "T/com.x.word/a/b", "T/com.x.word/a/b/c"] {
            try sandbox.setAge(10, of: sandbox.root.appending(path: path))
        }
        let old = try #require(Cleaner.newestChange(in: folder))
        #expect(old < Date().addingTimeInterval(-9 * 86_400))
        try sandbox.file("T/com.x.word/a/b/c/fresh.bin")
        for path in ["T/com.x.word", "T/com.x.word/a", "T/com.x.word/a/b", "T/com.x.word/a/b/c"] {
            try sandbox.setAge(10, of: sandbox.root.appending(path: path))
        }
        let newest = try #require(Cleaner.newestChange(in: folder))
        #expect(newest > Date().addingTimeInterval(-60))
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

    /// A later clean that trashes nothing must not forget what an earlier one trashed.
    @Test func aLaterCleanKeepsTheEarlierItemsInTheManifest() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let stillThere = try sandbox.file(".Trash/Tool.dmg", bytes: 10)
        let earlier = TrashedItem(original: sandbox.root.appending(path: "Downloads/Tool.dmg"), inTrash: stillThere, size: 10)
        let first = CleanOutcome(steps: [StepOutcome(id: "a", title: "a", method: .trash, size: 10, cleanedItemIDs: [],
                                                     failures: [], trashed: [earlier])],
                                 freeBefore: 0, freeAfter: 0, trashedSize: 10, duration: 0, logURL: nil, started: Date())
        PutBack.save(first, home: sandbox.root)
        let second = CleanOutcome(steps: [StepOutcome(id: "b", title: "b", method: .delete, size: 5, cleanedItemIDs: ["x"], failures: [])],
                                  freeBefore: 0, freeAfter: 0, trashedSize: 0, duration: 0, logURL: nil, started: Date())
        PutBack.save(second, home: sandbox.root)
        #expect(PutBack.pending(home: sandbox.root)?.items == [earlier])
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

struct FnmAliasTests {
    /// fnm's default alias lands on `<version>/installation`; the version is the folder above.
    @Test func readsTheDefaultThroughTheInstallationLink() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let versions = sandbox.root.appending(path: "Library/Application Support/fnm/node-versions")
        try sandbox.file("Library/Application Support/fnm/node-versions/v18.19.0/installation/bin/node", bytes: 25_000_000)
        try sandbox.file("Library/Application Support/fnm/node-versions/v22.3.0/installation/bin/node", bytes: 25_000_000)
        try sandbox.file("Library/Application Support/fnm/node-versions/v16.20.2/installation/bin/node", bytes: 25_000_000)
        let aliases = sandbox.root.appending(path: "Library/Application Support/fnm/aliases")
        try FileManager.default.createDirectory(at: aliases, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: aliases.appending(path: "default"),
                                                   withDestinationURL: versions.appending(path: "v18.19.0/installation"))

        let result = await ToolchainScanner.scan(ScanContext(home: sandbox.root))
        let offered = result.findings.flatMap(\.items).map(\.title)
        #expect(offered == ["Node v16.20.2"])
        #expect(Set(result.protected.map(\.title)) == ["Node v18.19.0", "Node v22.3.0"])
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

@MainActor
struct MenuBarTests {
    @Test func theWeeklyCheckIsDueAfterSevenDays() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let model = AppModel(home: sandbox.root)
        model.settings.lastScanDate = Date()
        #expect(!model.isWeeklyCheckDue)
        model.settings.lastScanDate = Date().addingTimeInterval(-8 * 86_400)
        #expect(model.isWeeklyCheckDue)
        model.settings.lastScanDate = nil
        #expect(model.isWeeklyCheckDue)
    }

    @Test func cleanSafeTicksOnlyTheSafeTierEverywhereAndOpensTheOverviewsConfirmation() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let model = AppModel(home: sandbox.root)
        let developer = model.cleanUp(.developer)
        let system = model.cleanUp(.system)
        let safe = finding(id: "safe", items: [FindingItem(id: "s/1", title: "", detail: "", size: 10, paths: [sandbox.root.appending(path: ".npm/_cacache")])])
        let review = finding(id: "review", tier: .review, method: .trash, items: [FindingItem(id: "r/1", title: "", detail: "", size: 20, paths: [sandbox.root.appending(path: "Downloads/x.dmg")])])
        let logs = finding(id: "logs", area: .cachesLogs, items: [FindingItem(id: "c/1", title: "", detail: "", size: 5, paths: [sandbox.root.appending(path: "Library/Logs/x")])])
        developer.show(findings: [safe, review])
        system.show(findings: [logs])
        developer.binding(for: review.items[0]).wrappedValue = true
        #expect(developer.selection == ["s/1", "r/1"])
        #expect(model.safeSize == 15)
        #expect(model.largestAreas(1).first?.size == 30)

        // Results from the parts' own scans count: the overview needs no scan of its own first.
        model.sidebarSelection = .apps
        model.cleanSafe()
        #expect(model.overviewPhase == .results)
        #expect(model.sidebarSelection == .overview)
        #expect(developer.selection == ["s/1"])
        #expect(model.included == [.group(.developer), .group(.system)])
        #expect(model.showingOverviewReview)
        #expect(model.runPlan.steps.map(\.id) == ["logs", "safe"])
        #expect(model.runSize == 15)
    }

    /// The menu bar once offered the whole Safe tier, 25.8 GB, while its button and the overview
    /// agreed on 8.4 GB: the newest device support is Safe, and kept unless the user ticks it.
    @Test func theMenuBarOffersOnlyWhatItsButtonRemoves() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let model = AppModel(home: sandbox.root)
        let developer = model.cleanUp(.developer)
        let caches = sandbox.root.appending(path: "Library/Caches")
        let safe = finding(items: [
            FindingItem(id: "s/old", title: "", detail: "", size: 10, paths: [caches.appending(path: "old")]),
            FindingItem(id: "s/newest", title: "", detail: "", size: 40, paths: [caches.appending(path: "newest")], preselected: false),
        ])
        developer.show(findings: [safe])
        #expect(model.foundSize == 50)
        #expect(developer.selectedSize == 10)
        #expect(model.safeSize == 10)

        developer.binding(for: safe.items[1]).wrappedValue = true
        model.cleanSafe()
        #expect(developer.selection == ["s/old"])
        #expect(model.runSize == model.safeSize)
    }
}

@MainActor
struct AreaGroupTests {
    private func item(_ id: String, _ size: Int64) -> FindingItem {
        FindingItem(id: id, title: "", detail: "", size: size)
    }

    @Test func everyCleanUpAreaBelongsToOneCleanUp() {
        let filed = AreaGroup.allCases.flatMap(\.areas)
        #expect(Set(filed) == Set(Area.cleanUp))
        #expect(filed.count == Area.cleanUp.count)
        #expect(Area.largeFiles.group == .downloads)
        #expect(Area.leftovers.group == nil)
        #expect(SidebarItem.parts == [.group(.system), .group(.developer), .group(.downloads), .performance, .apps])
    }

    @Test func eachCleanUpKeepsItsOwnFindingsAndTheOverviewAddsThemUp() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let model = AppModel(home: sandbox.root)
        model.cleanUp(.developer).show(findings: [
            finding(id: "derived", area: .xcode, items: [item("x/1", 30)]),
            finding(id: "caches", area: .packageCaches, tier: .review, method: .trash, items: [item("p/1", 10)]),
        ])
        model.cleanUp(.system).show(findings: [
            finding(id: "logs", area: .cachesLogs, items: [item("c/1", 50)]),
            finding(id: "bin", area: .trash, tier: .review, items: [item("t/1", 20)]),
        ])
        model.cleanUp(.downloads).show(findings: [
            finding(id: "zip", area: .largeFiles, tier: .review, method: .trash, items: [item("l/1", 5)]),
        ])
        #expect(model.cleanUp(.developer).foundSize == 40)
        #expect(model.cleanUp(.developer).selectedSize == 30)
        #expect(model.cleanUp(.system).foundSize == 70)
        #expect(model.cleanUp(.system).selectedSize == 50)
        #expect(model.foundSize == 115)
        #expect(model.safeSize == 80)
        #expect(model.largestAreas(2).map(\.area) == [.cachesLogs, .xcode])
        #expect(model.areas(in: .developer) == AreaGroup.developer.areas)
        #expect(model.areas(in: .system) == [.cachesLogs, .trash, .snapshots])
        #expect(model.areas(in: .downloads) == [.largeFiles])
        // Not ticked anywhere, so nothing for Run to do there; the others have.
        #expect(!model.hasWork(.group(.downloads)))
        #expect(model.hasWork(.group(.developer)))
        #expect(model.hasWork(.group(.system)))
        #expect(!model.hasWork(.apps))
    }

    @Test func everyEntryLeadsSomewhereAtAnyTime() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let model = AppModel(home: sandbox.root)
        model.select(.group(.developer))
        #expect(model.sidebarSelection == .group(.developer))
        #expect(model.theme == AreaGroup.developer.theme)
        model.select(.group(.downloads))
        #expect(model.theme == AreaGroup.downloads.theme)
        model.select(.overview)
        #expect(model.theme == SidebarItem.overview.theme)
        #expect(model.overviewPhase == .home)
    }

    @Test func leftoversAndInstallersBelongToApplicationsNotTheCleanUp() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let model = AppModel(home: sandbox.root)
        #expect(!Area.cleanUp.contains(.leftovers))
        #expect(!Area.cleanUp.contains(.installers))
        #expect(!model.listedAreas.contains(.leftovers))
        #expect(!model.enabledAreas.contains(.installers))
        // Switching one on by hand does not bring it back into the scan.
        model.forcedAreas = [.leftovers]
        #expect(!model.enabledAreas.contains(.leftovers))
        #expect(!model.overviewParts.contains(.group(.developer)) || model.areas(in: .developer).isEmpty == false)
    }

    @Test func anAreaThatWasSplitStaysSwitchedOff() throws {
        let name = "AreaGroupTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(["installersTrash", "xcode", "no-such-area"], forKey: "disabledAreas")
        #expect(Area.stored(forKey: "disabledAreas", in: defaults) == [.trash, .largeFiles, .xcode])
        #expect(Area.stored(forKey: "forcedAreas", in: defaults).isEmpty)
    }

    @Test func aGroupEntryIsBusyUntilItsLastAreaIsDone() {
        #expect(CleanUpModel.combined([.idle, .idle]) == .idle)
        #expect(CleanUpModel.combined([.queued, .idle, .queued]) == .queued)
        #expect(CleanUpModel.combined([.finished, .queued]) == .scanning)
        #expect(CleanUpModel.combined([.finished, .scanning, .skipped("stopped")]) == .scanning)
        #expect(CleanUpModel.combined([.finished, .skipped("stopped")]) == .finished)
        #expect(CleanUpModel.combined([.skipped("stopped"), .idle, .skipped("stopped")]) == .skipped("stopped"))
    }
}

@MainActor
struct SystemCleanUpTests {
    private func item(_ id: String, _ size: Int64, unknown: Bool = false) -> FindingItem {
        FindingItem(id: id, title: "", detail: "", size: size, sizeUnknown: unknown)
    }

    @Test func systemCleanUpLooksAtTheSystemAreasOnItsOwn() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let model = AppModel(home: sandbox.root)
        let system = model.cleanUp(.system)
        #expect(system.areas == AreaGroup.system.areas)
        #expect(model.cleanUp(.developer).areas == AreaGroup.developer.areas)
        #expect(system.phase == .home)

        // Reachable at any time, like Applications, with nothing scanned by the overview.
        model.select(.group(.system))
        #expect(model.sidebarSelection == .group(.system))
        #expect(model.theme == AreaGroup.system.theme)
        #expect(model.overviewPhase == .home)

        // Results on one side leave the others alone.
        system.show(findings: [
            finding(id: "logs", area: .cachesLogs, items: [item("c/1", 50)]),
            finding(id: "bin", area: .trash, tier: .review, items: [item("t/1", 20)]),
        ])
        #expect(system.phase == .results)
        #expect(system.foundSize == 70)
        #expect(system.selectedSize == 50)
        #expect(model.cleanUp(.developer).phase == .home)
        #expect(model.cleanUp(.developer).findings.isEmpty)
        #expect(system.largestAreas(3).map(\.area) == [.cachesLogs, .trash])
    }

    @Test func aTileCleansItsAreaAloneAndTheRoundButtonEverything() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let model = AppModel(home: sandbox.root)
        let system = model.cleanUp(.system)
        let logs = finding(id: "logs", area: .cachesLogs, items: [
            FindingItem(id: "c/1", title: "", detail: "", size: 50, paths: [sandbox.root.appending(path: "Library/Caches/x")]),
        ])
        let bin = finding(id: "bin", area: .trash, tier: .review, items: [
            FindingItem(id: "t/1", title: "", detail: "", size: 20, paths: [sandbox.root.appending(path: ".Trash/x")]),
        ])
        let snapshots = finding(id: "snap", area: .snapshots, tier: .review, method: .adminCommand,
                                items: [FindingItem(id: "s/1", title: "", detail: "", size: 0, command: ["/usr/bin/tmutil"], sizeUnknown: true)])
        system.show(findings: [logs, bin, snapshots])
        system.binding(for: bin.items[0]).wrappedValue = true
        system.binding(for: snapshots.items[0]).wrappedValue = true

        system.review(area: .trash)
        #expect(system.showingReview)
        #expect(system.plan.steps.map(\.id) == ["bin"])
        #expect(!system.planHasUnknownSize)

        system.review(area: .snapshots)
        #expect(system.plan.steps.map(\.id) == ["snap"])
        #expect(system.planHasUnknownSize)

        system.review()
        #expect(system.plan.steps.map(\.id) == ["logs", "bin", "snap"])
        #expect(system.selectionHasUnknownSize)
    }

    @Test func theManagerOpensOneAreaAndTicksItAsAWhole() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let model = AppModel(home: sandbox.root)
        let system = model.cleanUp(.system)
        let backups = finding(id: "backups", area: .snapshots, tier: .careful, method: .trash, items: [item("b/1", 30), item("b/2", 10)])
        let logs = finding(id: "logs", area: .cachesLogs, items: [item("c/1", 50), FindingItem(id: "c/kept", title: "", detail: "", size: 5, preselected: false)])
        system.show(findings: [logs, backups])
        #expect(system.selection == ["c/1"])

        system.open(.snapshots)
        #expect(system.openArea == .snapshots)
        system.selectAll(in: .snapshots)
        #expect(system.selection == ["c/1", "b/1", "b/2"])
        system.selectNone(in: .snapshots)
        system.selectAll(in: .cachesLogs)
        #expect(system.selection == ["c/1", "c/kept"])
        system.selectSafe(in: .cachesLogs)
        #expect(system.selection == ["c/1"])
        system.showResults()
        #expect(system.openArea == nil)
        #expect(system.phase == .results)
    }
}

@MainActor
struct OverviewRunTests {
    private func waitUntilDone(_ model: AppModel) async throws {
        for _ in 0..<400 where model.overviewPhase != .done {
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    @Test func runGoesThroughEveryTickedCleanUpAndKeepsOneReceipt() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let npm = try sandbox.file(".npm/_cacache/blob.bin").deletingLastPathComponent()
        let logs = try sandbox.file("Library/Logs/app/out.log").deletingLastPathComponent()
        let zip = try sandbox.file("Downloads/big.zip")

        let model = AppModel(home: sandbox.root)
        model.cleanUp(.developer).show(findings: [
            finding(id: "caches", items: [FindingItem(id: "c/npm", title: "", detail: "", size: 10, paths: [npm])]),
        ])
        model.cleanUp(.system).show(findings: [
            finding(id: "logs", area: .cachesLogs, items: [FindingItem(id: "l/app", title: "", detail: "", size: 10, paths: [logs])]),
        ])
        model.cleanUp(.downloads).show(findings: [
            finding(id: "zip", area: .largeFiles, tier: .review, method: .trash, items: [FindingItem(id: "z/1", title: "", detail: "", size: 10, paths: [zip])]),
        ])
        model.cleanUp(.downloads).binding(for: FindingItem(id: "z/1", title: "", detail: "", size: 10)).wrappedValue = true
        model.reviewSafe()
        // Safe only: the ticked download is left alone, and so is the part that is unticked on the overview.
        #expect(model.included == [.group(.developer), .group(.system)])
        #expect(model.runPlan.steps.map(\.id) == ["logs", "caches"])
        model.inclusion(of: .group(.system)).wrappedValue = false
        #expect(model.runPlan.steps.map(\.id) == ["caches"])
        #expect(model.runSize == 10)

        model.run()
        #expect(model.overviewPhase == .running)
        try await waitUntilDone(model)

        #expect(model.overviewPhase == .done)
        #expect(!Files.exists(npm))
        #expect(Files.exists(logs))
        #expect(Files.exists(zip))
        #expect(model.overviewOutcome?.steps.map(\.id) == ["caches"])
        #expect(model.cleanUp(.developer).phase == .done)
        #expect(model.cleanUp(.system).phase == .results)
        #expect(model.foundSize == 20)
        model.showOverviewResults()
        #expect(model.overviewPhase == .results)
    }

    @Test func receiptsOfSeveralPartsMergeIntoOne() {
        let started = Date()
        let first = CleanOutcome(steps: [StepOutcome(id: "a", title: "", method: .delete, size: 5, cleanedItemIDs: ["a/1"], failures: [], skippedReason: nil)],
                                 freeBefore: 100, freeAfter: 105, trashedSize: 0, duration: 2, logURL: URL(fileURLWithPath: "/tmp/a.log"), started: started)
        let second = CleanOutcome(steps: [StepOutcome(id: "b", title: "", method: .trash, size: 7, cleanedItemIDs: ["b/1"], failures: [], skippedReason: nil)],
                                  freeBefore: 105, freeAfter: 105, trashedSize: 7, duration: 3, logURL: nil, started: started.addingTimeInterval(2))
        let merged = CleanOutcome.merged([first, second])
        #expect(merged?.steps.map(\.id) == ["a", "b"])
        #expect(merged?.freeBefore == 100)
        #expect(merged?.freeAfter == 105)
        #expect(merged?.reclaimed == 5)
        #expect(merged?.trashedSize == 7)
        #expect(merged?.duration == 5)
        #expect(merged?.logURL?.path == "/tmp/a.log")
        #expect(merged?.started == started)
        #expect(CleanOutcome.merged([]) == nil)
    }
}

struct DiskInfoTests {
    @Test func usedSpaceLeavesOutWhatIsPurgeable() {
        let disk = DiskInfo(name: "Macintosh HD", capacity: 1000, free: 100, purgeable: 50)
        #expect(disk.used == 850)
        #expect(disk.isLow)
    }
}
