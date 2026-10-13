//
//  OpenAppTests.swift
//  SwiftMacCleanerTests
//
//  A cache waits while the app that keeps it is open, and the confirmation offers to ask the app to
//  quit. No app is ever quit here: each test puts its own list where the open apps would be.
//

import Foundation
import SwiftUI
import Testing
@testable import SwiftMacCleaner

/// A throwaway folder that stands in for a home directory, with a store of its own for settings.
private struct Sandbox {
    let root: URL
    let defaults = MemoryDefaults()

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "mdc-open-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    @MainActor
    func model(open apps: [OpenApp]) -> AppModel {
        let model = AppModel(home: root, settings: AppSettings(defaults: defaults))
        model.openApps.list = { apps }
        return model
    }

    /// A folder with one file in it, which is what a cache is to the cleaner.
    @discardableResult
    func folder(_ path: String) throws -> URL {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try Data(repeating: 7, count: 16).write(to: url.appending(path: "blob"))
        return url
    }
}

private let chrome = OpenApp(bundleID: "com.google.Chrome", name: "Google Chrome")
private let xcode = OpenApp(bundleID: "com.apple.dt.Xcode", name: "Xcode")

private func cache(_ id: String, _ size: Int64, at url: URL, keptBy: String?) -> FindingItem {
    FindingItem(id: id, title: url.lastPathComponent, detail: "", size: size, paths: [url], keptBy: keptBy)
}

private func caches(_ items: [FindingItem]) -> Finding {
    Finding(id: "caches.apps", area: .cachesLogs, aftermath: .rebuilds, title: "App caches", summary: "", explanation: "",
            method: .delete, actionTarget: "", items: items, keepsChanging: true)
}

struct OpenAppTests {
    @Test func anAppKeepsWhatIsFiledUnderItsNames() {
        // By its identifier, by something that starts with it, by its own name, or by its maker's.
        #expect(chrome.keeps("com.google.Chrome"))
        #expect(chrome.keeps("com.google.Chrome.helper"))
        #expect(chrome.keeps("Google"))
        #expect(chrome.keeps("com.google"))
        #expect(chrome.keeps("Google Chrome"))
        #expect(!chrome.keeps("com.google.Drive"))
        #expect(!chrome.keeps("com.googlecode.iterm2"))
        #expect(!chrome.keeps("com.onevcat.Kingfisher.ImageCache.default"))
        #expect(!chrome.keeps("com"))
        #expect(!chrome.keeps("Chrome Canary"))
        #expect(!chrome.keeps(""))

        let coolApp = OpenApp(bundleID: "asia.coolapp.chat-desktop", name: "CoolApp")
        #expect(coolApp.keeps("asia.coolapp.chat-desktop.ShipIt"))
        #expect(coolApp.keeps("asia.coolapp"))
        #expect(!coolApp.keeps("asia"))
        #expect(OpenApp(bundleID: "com.spotify.client", name: "Spotify").keeps("Spotify"))
        #expect(OpenApp(bundleID: "com.anthropic.claudefordesktop", name: "Claude").keeps("claude"))
        #expect(OpenApp(bundleID: "com.jetbrains.intellij", name: "IntelliJ IDEA").keeps("JetBrains"))
        // An identifier too short to have a maker in it keeps nothing by one.
        #expect(!OpenApp(bundleID: "google.chrome", name: "X").keeps("chrome"))
    }

    @Test func itemsWaitOnlyForAppsThatAreOpenAndKeepThem() {
        let here = URL(fileURLWithPath: "/Users/someone/Library/Caches")
        let items = [
            cache("c/chrome", 10, at: here.appending(path: "Google"), keptBy: "Google"),
            cache("c/spotify", 20, at: here.appending(path: "com.spotify.client"), keptBy: "com.spotify.client"),
            cache("c/nobody", 30, at: here.appending(path: "clang"), keptBy: nil),
        ]
        #expect(items.waiting(for: [chrome]) == ["c/chrome": [chrome]])
        #expect(items.waiting(for: [xcode]).isEmpty)
        #expect(items.waiting(for: []).isEmpty)
        let reason = Cleaner.waitingReason("/x/Google", for: [chrome, xcode])
        #expect(reason == "/x/Google: Google Chrome and Xcode are still open, so it was left alone")
        #expect(reason.contains(Cleaner.openAppReason))
    }

    /// The button and the confirmation show one figure: what is ticked, less what waits, and never a guess.
    @Test func aPlansFigureLeavesOutWhatWaitsAndWhatIsOnlyAGuess() {
        let here = URL(fileURLWithPath: "/Users/someone/Library/Caches")
        let plan = CleanPlan.make(findings: [caches([
            cache("c/chrome", 10, at: here.appending(path: "Google"), keptBy: "Google"),
            cache("c/other", 30, at: here.appending(path: "clang"), keptBy: nil),
        ])], selection: ["c/chrome", "c/other"])
        #expect(plan.steps.first?.checksFreshness == false)
        #expect(plan.totalSize == 40)
        #expect(plan.size() == 40)
        #expect(plan.size(waiting: ["c/chrome"]) == 30)
        #expect(plan.waitingSize(waiting: ["c/chrome"]) == 10)
        #expect(plan.size(leavingOut: ["caches.apps"]) == 0)
        #expect(plan.waitingSize(blocked: ["caches.apps"], waiting: ["c/chrome"]) == 0)

        let task = CleanStep(id: "maintenance/purgeable", title: "Free Up Purgeable Space", aftermath: .rebuilds, method: .command,
                             summary: "", size: 1_700, operations: [CleanOperation(itemID: "maintenance/purgeable", kind: .run(["/usr/bin/true"]), size: 1_700)],
                             sizeIsEstimate: true)
        let withTask = CleanPlan(steps: plan.steps + [task])
        #expect(withTask.totalSize == 1_740)
        #expect(withTask.size() == 40)
    }

    @Test func theCleanerLeavesAWaitingItemAndTakesTheRestEvenWhenItChanged() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let kept = try sandbox.folder("Library/Caches/Google")
        let busy = try sandbox.folder("Library/Caches/clang")
        let scanned = Date()
        // Written to after the scan, as the cache of anything that is running always is.
        try FileManager.default.setAttributes([.modificationDate: scanned.addingTimeInterval(60)],
                                              ofItemAtPath: busy.appending(path: "blob").path)
        let plan = CleanPlan.make(findings: [caches([
            cache("c/chrome", 10, at: kept, keptBy: "Google"),
            cache("c/other", 30, at: busy, keptBy: nil),
        ])], selection: ["c/chrome", "c/other"])
        let waiting = ["c/chrome": Cleaner.waitingReason(kept.path, for: [chrome])]

        let outcome = await Cleaner.run(plan: plan, safety: SafetyGuard(root: sandbox.root), waiting: waiting, scannedAt: scanned) { _ in }
        let step = try #require(outcome.steps.first)
        #expect(step.cleanedItemIDs == ["c/other"])
        #expect(step.skippedItems["c/chrome"]?.contains("Google Chrome is still open") == true)
        #expect(step.failures.isEmpty)
        #expect(Files.exists(kept))
        #expect(!Files.exists(busy))

        // The same change still stops anything that does not change all the time by itself.
        let stale = try sandbox.folder("Code/app/node_modules")
        try FileManager.default.setAttributes([.modificationDate: scanned.addingTimeInterval(60)],
                                              ofItemAtPath: stale.appending(path: "blob").path)
        let careful = Finding(id: "projects.stale", area: .projects, aftermath: .rebuilds, title: "", summary: "", explanation: "",
                              method: .delete, actionTarget: "", items: [cache("p/1", 5, at: stale, keptBy: nil)])
        let second = await Cleaner.run(plan: CleanPlan.make(findings: [careful], selection: ["p/1"]),
                                       safety: SafetyGuard(root: sandbox.root), scannedAt: scanned) { _ in }
        #expect(second.steps.first?.skippedItems["p/1"]?.contains("changed since the scan") == true)
        #expect(Files.exists(stale))
    }
}

@MainActor
struct OpenAppCleanUpTests {
    @Test func aCacheWaitsForItsAppAndGoesOnceTheAppHasQuit() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let google = try sandbox.folder("Library/Caches/Google")
        let clang = try sandbox.folder("Library/Caches/clang")
        let model = sandbox.model(open: [chrome])
        let system = model.cleanUp(.system)
        system.show(findings: [caches([
            cache("c/chrome", 10, at: google, keptBy: "Google"),
            cache("c/other", 30, at: clang, keptBy: nil),
        ])])

        // Both are ticked, and the figures say how much of that can go right now.
        #expect(system.selectedSize == 40)
        #expect(system.cleanableSize() == 30)
        #expect(system.waitingSize() == 10)
        #expect(system.waitingItems() == ["c/chrome": [chrome]])
        #expect(system.blockingApps() == [BlockingApp(app: chrome, size: 10)])
        #expect(system.keepers(of: system.findings[0].items[0]) == [chrome])
        #expect(model.included == [])
        model.select(.smart)
        #expect(model.runSize == 30)
        #expect(model.runWaitingSize == 10)
        #expect(model.runBlockingApps == [BlockingApp(app: chrome, size: 10)])
        #expect(model.runWaitingItems.keys.sorted() == ["c/chrome"])

        // Cleaning without quitting leaves the one cache where it is, and says why.
        let first = try #require(await system.runClean(area: nil))
        #expect(first.steps.first?.cleanedItemIDs == ["c/other"])
        #expect(first.steps.first?.skippedItems["c/chrome"]?.contains(Cleaner.openAppReason) == true)
        #expect(Files.exists(google))
        #expect(!Files.exists(clang))
        #expect(system.findings.flatMap(\.items).map(\.id) == ["c/chrome"])

        // Asked to quit, the app goes off the list, and nothing waits any more.
        system.showResults()
        system.quit(chrome)
        #expect(model.openApps.apps.isEmpty)
        #expect(system.waitingItems().isEmpty)
        #expect(system.cleanableSize() == 10)
        #expect(system.blockingApps().isEmpty)
        let second = try #require(await system.runClean(area: nil))
        #expect(second.steps.first?.cleanedItemIDs == ["c/chrome"])
        #expect(!Files.exists(google))
    }

    @Test func aGroupThatWaitsAsAWholeCountsForItsAppToo() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let model = sandbox.model(open: [chrome, xcode])
        let developer = model.cleanUp(.developer)
        let derived = Finding(id: "xcode.derivedData", area: .xcode, aftermath: .rebuilds, title: "Xcode DerivedData", summary: "",
                              explanation: "", method: .delete, actionTarget: "",
                              items: [cache("d/1", 400, at: sandbox.root.appending(path: "Library/Developer/Xcode/DerivedData/App"), keptBy: nil)],
                              waitsFor: .xcode)
        let npm = Finding(id: "packages.caches", area: .packageCaches, aftermath: .rebuilds, title: "Package manager caches", summary: "",
                          explanation: "", method: .delete, actionTarget: "",
                          items: [cache("p/1", 300, at: sandbox.root.appending(path: ".npm/_cacache"), keptBy: nil)])
        developer.show(findings: [derived, npm])
        #expect(developer.selectedSize == 700)
        #expect(developer.blockedSteps(in: developer.plan).keys.sorted() == ["xcode.derivedData"])
        #expect(developer.activeChecks().keys.sorted() == ["xcode.derivedData"])
        #expect(developer.cleanableSize() == 300)
        #expect(developer.blockingApps() == [BlockingApp(app: xcode, size: 400)])

        // The list is all that is asked while one stands in, so quitting there is seen at once.
        developer.quit(xcode)
        #expect(developer.blockedSteps(in: developer.plan).isEmpty)
        #expect(developer.cleanableSize() == 700)
    }

    @Test func whatTheAppCannotEmptyFromTheTrashIsShownAndLeftOutOfTheFigure() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let mine = sandbox.root.appending(path: ".Trash/old.dmg")
        let roots = sandbox.root.appending(path: ".Trash/Installed.app/Contents/big.bin")
        for (url, megabytes) in [(mine, 6), (roots, 8)] {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(repeating: 7, count: megabytes * 1_000_000).write(to: url)
        }
        let context = ScanContext(home: sandbox.root)
        let result = await TrashScanner.scan(context) { $0.lastPathComponent != "Installed.app" }
        let finding = try #require(result.findings.first)
        let item = try #require(finding.items.first)
        #expect(item.paths.map(\.lastPathComponent) == ["old.dmg"])
        #expect(item.title == "Everything in the Trash that is yours")
        #expect(item.size >= 6_000_000 && item.size < 7_000_000)
        #expect(finding.summary.hasPrefix("1 item"))
        let left = try #require(result.protected.first)
        #expect(left.rule == .notYours)
        #expect(left.title == "Installed.app in the Trash")
        #expect((left.size ?? 0) >= 8_000_000)
        #expect(left.why.contains("Finder"))

        // With nothing of the user's own there, there is nothing to offer and still something to show.
        let none = await TrashScanner.scan(context) { _ in false }
        #expect(none.findings.isEmpty)
        #expect(none.protected.count == 1)
        // And everything in a Trash the user filled alone is theirs.
        let all = await TrashScanner.scan(context)
        #expect(all.protected.isEmpty)
        #expect(all.findings.first?.items.first?.title == "Everything in the Trash")
    }
}
