//
//  AppsTests.swift
//  Mac Disk CleanerTests
//
//  The Applications screen: which files belong to which app, what an uninstall moves, and how update
//  feeds are read.
//

import Foundation
import SwiftUI
import Testing
@testable import Mac_Disk_Cleaner

/// A throwaway folder that stands in for a home directory, with a few apps in it.
private struct Sandbox {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "mdc-apps-\(UUID().uuidString)")
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

    /// An app bundle with the least an app needs: an Info.plist and a program.
    @discardableResult
    func app(_ name: String, id: String, in folder: String = "Applications", version: String = "1.0",
             extra: [String: Any] = [:]) throws -> URL {
        let bundle = root.appending(path: "\(folder)/\(name).app")
        var info: [String: Any] = [
            "CFBundleIdentifier": id, "CFBundleName": name, "CFBundleExecutable": name,
            "CFBundleShortVersionString": version, "CFBundleVersion": "100",
        ]
        info.merge(extra) { $1 }
        try FileManager.default.createDirectory(at: bundle.appending(path: "Contents/MacOS"), withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: bundle.appending(path: "Contents/Info.plist"))
        try Data(repeating: 1, count: 4096).write(to: bundle.appending(path: "Contents/MacOS/\(name)"))
        return bundle
    }
}

private func identity(_ id: String, _ bundleID: String, names: Set<String> = [], executable: String = "",
                      groups: [String] = []) -> AppIdentity {
    AppIdentity(id: id, bundleID: bundleID, names: names, executable: executable, groups: groups)
}

struct AppFileFinderTests {
    @Test func anItemGoesToTheAppWithTheLongestMatchingIdentifier() {
        let owners = AppFileFinder.Owners([identity("a", "com.maker.editor"), identity("b", "com.maker.editor.pro")])
        #expect(owners.owner(of: "com.maker.editor", match: .identifier) == "a")
        #expect(owners.owner(of: "com.maker.editor.helper", match: .identifier) == "a")
        #expect(owners.owner(of: "com.maker.editor.savedState", match: .identifier) == "a")
        #expect(owners.owner(of: "com.maker.editor.pro", match: .identifier) == "b")
        #expect(owners.owner(of: "com.maker.editor.pro.plist", match: .identifier) == "b")
        #expect(owners.owner(of: "COM.Maker.Editor.plist", match: .identifier) == "a")
        // A longer word is another app, not a helper of this one.
        #expect(owners.owner(of: "com.maker.editorial", match: .identifier) == nil)
    }

    @Test func aTwoPartIdentifierClaimsOnlyItsOwnName() {
        let owners = AppFileFinder.Owners([identity("a", "com.maker")])
        #expect(owners.owner(of: "com.maker", match: .identifier) == "a")
        #expect(owners.owner(of: "com.maker.something", match: .identifier) == nil)
    }

    @Test func aNameTwoAppsShareOrAMakerUsesBelongsToNoApp() {
        let owners = AppFileFinder.Owners([
            identity("a", "com.x.one", names: ["notes"]),
            identity("b", "org.y.two", names: ["notes", "google"]),
            identity("c", "com.z.three", names: ["sketchbook"]),
        ])
        #expect(owners.owner(of: "Notes", match: .identifierOrName) == nil)
        #expect(owners.owner(of: "Google", match: .identifierOrName) == nil)
        #expect(owners.owner(of: "Sketchbook", match: .identifierOrName) == "c")
        // Preferences and containers go by identifier alone.
        #expect(owners.owner(of: "Sketchbook", match: .identifier) == nil)
    }

    @Test func aSharedContainerNeedsASingleOwner() {
        let owners = AppFileFinder.Owners([
            identity("word", "com.suite.word", groups: ["TEAM1.suite", "TEAM1.word"]),
            identity("sheet", "com.suite.sheet", groups: ["TEAM1.suite"]),
        ])
        #expect(owners.owner(of: "TEAM1.word", match: .group) == "word")
        #expect(owners.owner(of: "TEAM1.suite", match: .group) == nil)
        #expect(owners.owner(of: "group.com.someone.else", match: .group) == nil)
    }

    @Test func crashReportsAreFiledUnderTheProgramName() {
        let owners = AppFileFinder.Owners([
            identity("a", "com.x.relay", executable: "Relay"),
            identity("b", "com.x.one", executable: "Electron"),
            identity("c", "com.x.two", executable: "Electron"),
        ])
        #expect(owners.owner(of: "Relay-2026-09-14-101502.ips", match: .crashReport) == "a")
        #expect(owners.owner(of: "Relay_2026-09-14-101502_Mac.crash", match: .crashReport) == "a")
        #expect(owners.owner(of: "RelayHelper-2026-09-14-101502.ips", match: .crashReport) == nil)
        #expect(owners.owner(of: "Relay-2026-09-14.txt", match: .crashReport) == nil)
        // Two apps built on the same program name cannot be told apart.
        #expect(owners.owner(of: "Electron-2026-09-14-101502.ips", match: .crashReport) == nil)
    }

    @Test func findsAnAppsFolderInsideItsMakersFolder() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let support = "Library/Application Support"
        try sandbox.file("\(support)/Google/Chrome/Default/History")
        try sandbox.file("\(support)/Google/Chrome Canary/Default/History")
        try sandbox.file("\(support)/Google/GoogleUpdater/log")
        try sandbox.file("\(support)/JetBrains/IntelliJIdea2025.3/options/ide.xml")
        try sandbox.file("\(support)/JetBrains/IdeaIC2025.3/options/ide.xml")
        try sandbox.file("\(support)/BraveSoftware/Brave-Browser/Local State")
        try sandbox.file("Library/Caches/Google/Chrome/Default/Cache/data")
        let apps = [
            identity("chrome", "com.google.Chrome", names: ["google chrome"]),
            identity("idea", "com.jetbrains.intellij", names: ["intellij idea"]),
            identity("brave", "com.brave.Browser", names: ["brave browser"]),
            // Apple's own folders are never read this way.
            identity("keynote", "com.apple.iWork.Keynote", names: ["keynote"]),
        ]

        let found = AppFileFinder.files(for: apps, home: sandbox.root, safety: SafetyGuard(root: sandbox.root))
        func names(_ id: String) -> [String] { (found[id] ?? []).map { "\($0.kind.title): \($0.url.lastPathComponent)" }.sorted() }
        #expect(names("chrome") == ["Caches: Chrome", "Supporting Files: Chrome"])
        #expect(names("idea") == ["Supporting Files: IntelliJIdea2025.3"])
        #expect(names("brave") == ["Supporting Files: Brave-Browser"])
        #expect(found["keynote"] == nil)
    }

    @Test func listsWhatAnAppKeepsAndLeavesOutWhatMayNotBeTouched() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.file("Library/Application Support/Relay/data.db")
        try sandbox.file("Library/Application Support/com.example.other/data.db")
        try sandbox.file("Library/Caches/com.example.relay/cache.bin")
        try sandbox.file("Library/Caches/com.example.relay.ShipIt/update.zip")
        try sandbox.file("Library/Containers/com.example.relay/Data/file")
        try sandbox.file("Library/Preferences/com.example.relay.plist")
        try sandbox.file("Library/Preferences/ByHost/com.example.relay.ABCD.plist")
        try sandbox.file("Library/Saved Application State/com.example.relay.savedState/window.data")
        try sandbox.file("Library/Logs/Relay/today.log")
        try sandbox.file("Library/Logs/DiagnosticReports/Relay-2026-09-14-101502.ips")
        try sandbox.file("Library/LaunchAgents/com.example.relay.agent.plist")
        try sandbox.file("Library/Group Containers/TEAM9.com.example.relay/shared.db")
        let never = try sandbox.file("Library/HTTPStorages/com.example.relay/httpstorages.sqlite").deletingLastPathComponent()
        let relay = identity("relay", "com.example.relay", names: ["relay"], executable: "Relay", groups: ["TEAM9.com.example.relay"])

        let safety = SafetyGuard(root: sandbox.root, neverSuggest: [never.resolvingSymlinksInPath().path])
        let files = AppFileFinder.files(for: [relay], home: sandbox.root, safety: safety)["relay"] ?? []
        let byKind = Dictionary(grouping: files, by: \.kind).mapValues { $0.map(\.url.lastPathComponent).sorted() }
        #expect(byKind[.supportingFiles] == ["Relay", "com.example.relay.savedState"])
        #expect(byKind[.caches] == ["com.example.relay", "com.example.relay.ShipIt"])
        #expect(byKind[.containers] == ["TEAM9.com.example.relay", "com.example.relay"])
        #expect(byKind[.preferences] == ["com.example.relay.ABCD.plist", "com.example.relay.plist"])
        #expect(byKind[.logs] == ["Relay"])
        #expect(byKind[.crashes] == ["Relay-2026-09-14-101502.ips"])
        #expect(byKind[.loginItems] == ["com.example.relay.agent.plist"])
        // Another app's folder is not this app's, and a path on the Never Suggest list is not listed at all.
        #expect(!files.contains { $0.url.lastPathComponent == "com.example.other" })
        #expect(!files.contains { $0.url.path.contains("HTTPStorages") })
        // Listed in the order the kinds are shown.
        #expect(files.map(\.kind) == files.map(\.kind).sorted())
    }
}

struct AppScannerTests {
    @Test func listsAppsOneFolderDeepAndSkipsLinks() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let relay = try sandbox.app("Relay", id: "com.example.relay")
        try sandbox.app("Uninstall Suite", id: "com.example.suite.uninstaller", in: "Applications/Suite")
        try sandbox.app("Buried", id: "com.example.buried", in: "Applications/Suite/Extras")
        try sandbox.file("Applications/Suite/Manual.pdf")
        try FileManager.default.createSymbolicLink(at: sandbox.root.appending(path: "Applications/Alias.app"), withDestinationURL: relay)

        let bundles = AppScanner.bundles(in: [sandbox.root.appending(path: "Applications"), sandbox.root.appending(path: "Missing")])
        #expect(Set(bundles.map(\.lastPathComponent)) == ["Relay.app", "Uninstall Suite.app"])
    }

    @Test func readsAnAppsDetails() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let bundle = try sandbox.app("Relay Chat", id: "com.example.relay", version: "9.4", extra: [
            "CFBundleName": "Relay", "SUFeedURL": "https://example.com/appcast.xml",
        ])
        let described = try #require(AppScanner.describe(bundle, ownBundleID: "com.thetinydev.Mac-Disk-Cleaner"))
        #expect(described.app.name == "Relay Chat")
        #expect(described.app.bundleID == "com.example.relay")
        #expect(described.app.version == "9.4")
        #expect(described.app.build == "100")
        #expect(described.app.source == .other)
        #expect(described.app.feed == .sparkle(URL(string: "https://example.com/appcast.xml")!))
        #expect(!described.app.needsPassword)
        #expect(described.identity.names == ["relay chat", "relay"])
        #expect(described.identity.executable == "Relay Chat")

        // This app never lists itself, and a folder without an identifier is not an app.
        #expect(AppScanner.describe(bundle, ownBundleID: "com.example.relay") == nil)
        try FileManager.default.createDirectory(at: sandbox.root.appending(path: "Applications/Empty.app"), withIntermediateDirectories: true)
        #expect(AppScanner.describe(sandbox.root.appending(path: "Applications/Empty.app"), ownBundleID: "") == nil)
    }

    @Test func anAppFromTheAppStoreIsMarkedAndAskedThere() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let bundle = try sandbox.app("Tally", id: "com.example.tally")
        try sandbox.file("Applications/Tally.app/Contents/_MASReceipt/receipt")
        let app = try #require(AppScanner.describe(bundle, ownBundleID: "")).app
        #expect(app.source == .appStore)
        #expect(app.feed == .appStore)
    }

    @Test func readsAnIPhoneAppWrappedForTheMac() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let bundle = sandbox.root.appending(path: "Applications/Tower.app")
        let inner = bundle.appending(path: "Wrapper/Runner.app")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": "kh.example.tower", "CFBundleName": "Runner"],
                                           format: .xml, options: 0).write(to: inner.appending(path: "Info.plist"))
        try FileManager.default.createSymbolicLink(atPath: bundle.appending(path: "WrappedBundle").path, withDestinationPath: "Wrapper/Runner.app")

        let described = try #require(AppScanner.describe(bundle, ownBundleID: ""))
        #expect(described.app.name == "Tower")
        #expect(described.app.bundleID == "kh.example.tower")
        #expect(described.app.source == .appStore)
        #expect(described.app.feed == nil)
        #expect(described.identity.names == ["tower", "runner"])
    }

    @Test func measuresEachAppTogetherWithItsFiles() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.app("Relay", id: "com.example.relay")
        try sandbox.app("Tally", id: "com.example.tally")
        try sandbox.file("Library/Application Support/Relay/data.db", bytes: 300_000)
        try sandbox.file("Library/Preferences/com.example.relay.plist", bytes: 100)

        let apps = await AppScanner.scan(home: sandbox.root, roots: [sandbox.root.appending(path: "Applications")],
                                         safety: SafetyGuard(root: sandbox.root)) { _ in }
        #expect(Set(apps.map(\.name)) == ["Relay", "Tally"])
        let relay = try #require(apps.first { $0.name == "Relay" })
        #expect(relay.files.map(\.kind) == [.binaries, .supportingFiles, .preferences])
        #expect(relay.bundleFile?.url.lastPathComponent == "Relay.app")
        #expect(relay.files.allSatisfy { $0.size > 0 && !$0.sizeUnknown })
        #expect(relay.size >= 300_000)
        #expect(relay.kinds == [.binaries, .supportingFiles, .preferences])
        let tally = try #require(apps.first { $0.name == "Tally" })
        #expect(tally.files.count == 1)
    }

    @Test func readsWhereAnElectronAppLooksForUpdates() {
        let generic = "provider: generic\nurl: https://updates.example.com/desktop/\nupdaterCacheDirName: example-updater\n"
        #expect(AppScanner.electronFeed(fromUpdaterConfig: generic)?.absoluteString == "https://updates.example.com/desktop/latest-mac.yml")
        let github = "owner: someone\nrepo: 'thing'\nprovider: github\n"
        #expect(AppScanner.electronFeed(fromUpdaterConfig: github)?.absoluteString
                == "https://github.com/someone/thing/releases/latest/download/latest-mac.yml")
        // A private bucket has no file anyone may read, and plain http is not asked.
        #expect(AppScanner.electronFeed(fromUpdaterConfig: "provider: s3\nbucket: private\n") == nil)
        #expect(AppScanner.electronFeed(fromUpdaterConfig: "provider: generic\nurl: http://updates.example.com\n") == nil)
    }

    @Test func anAppCountsAsUnusedAfterSixMonthsWithoutBeingOpened() {
        let now = Date()
        func app(opened: Double?, installed: Double?) -> InstalledApp {
            InstalledApp(url: URL(fileURLWithPath: "/Applications/X.app"), name: "X", bundleID: "com.example.x",
                         lastOpened: opened.map { now.addingTimeInterval(-$0 * 86_400) },
                         installed: installed.map { now.addingTimeInterval(-$0 * 86_400) })
        }
        #expect(app(opened: 200, installed: 900).isUnused(asOf: now))
        #expect(!app(opened: 20, installed: 900).isUnused(asOf: now))
        // Never opened: what counts is how long ago it was installed.
        #expect(app(opened: nil, installed: 300).isUnused(asOf: now))
        #expect(!app(opened: nil, installed: 30).isUnused(asOf: now))
        #expect(!app(opened: nil, installed: nil).isUnused(asOf: now))
    }
}

struct UninstallerTests {
    private func app(_ name: String, at bundle: URL, files: [URL] = [], needsPassword: Bool = false) -> InstalledApp {
        InstalledApp(url: bundle, name: name, bundleID: "com.example.\(name.lowercased())", needsPassword: needsPassword,
                     files: [AppFile(url: bundle, kind: .binaries, size: 4000)] + files.map { AppFile(url: $0, kind: .supportingFiles, size: 100) })
    }

    @Test func movesTheAppFirstAndItsFilesAfterIt() {
        let bundle = URL(fileURLWithPath: "/Applications/Relay.app")
        let support = URL(fileURLWithPath: "/Users/someone/Library/Application Support/Relay")
        let relay = app("Relay", at: bundle, files: [support])
        let other = app("Tally", at: URL(fileURLWithPath: "/Applications/Tally.app"), needsPassword: true)

        let plan = Uninstaller.plan(for: [relay, other], selection: [bundle.path, support.path])
        #expect(plan.steps.count == 1)
        let step = plan.steps[0]
        #expect(step.id == Uninstaller.stepID(for: relay))
        #expect(step.title == "Relay")
        #expect(step.method == .trash)
        #expect(step.requiresFirst)
        #expect(step.size == 4100)
        #expect(step.operations.map(\.kind) == [.trash(bundle), .trash(support)])
        #expect(step.waitsFor == .app(bundleID: "com.example.relay", name: "Relay"))
        #expect(step.summary == "Move the app and 1 related item to the Trash")
        #expect(Uninstaller.bundles(in: [relay, other], selection: [bundle.path, support.path]) == [bundle])
        #expect(!Uninstaller.needsPassword([relay, other], selection: [bundle.path, support.path]))
        #expect(Uninstaller.needsPassword([relay, other], selection: [other.url.path]))
    }

    @Test func tickingOnlyFilesLeavesTheAppWhereItIs() throws {
        let bundle = URL(fileURLWithPath: "/Applications/Relay.app")
        let support = URL(fileURLWithPath: "/Users/someone/Library/Application Support/Relay")
        let relay = app("Relay", at: bundle, files: [support])

        let plan = Uninstaller.plan(for: [relay], selection: [support.path])
        let step = try #require(plan.steps.first)
        #expect(!step.requiresFirst)
        #expect(step.operations.map(\.kind) == [.trash(support)])
        #expect(step.title == "Relay: its files only")
        #expect(Uninstaller.bundles(in: [relay], selection: [support.path]).isEmpty)
    }

    /// An app outside the home folder may be moved only when the guard was told about that very bundle.
    @Test func anAppThatMayNotBeMovedKeepsItsFiles() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let elsewhere = try Sandbox()
        defer { elsewhere.remove() }
        let bundle = try elsewhere.app("Relay", id: "com.example.relay")
        let support = try sandbox.file("Library/Application Support/Relay/data.db").deletingLastPathComponent()
        let relay = app("Relay", at: bundle, files: [support])
        let plan = Uninstaller.plan(for: [relay], selection: [bundle.path, support.path])

        let outcome = await Cleaner.run(plan: plan, safety: SafetyGuard(root: sandbox.root)) { _ in }
        #expect(outcome.failureCount == 1)
        #expect(outcome.cleanedItemIDs.isEmpty)
        #expect(outcome.trashed.isEmpty)
        #expect(Files.exists(bundle))
        #expect(Files.exists(support))
    }

    @Test func movesANamedAppAndItsFilesToTheTrashAndPutsThemBack() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let elsewhere = try Sandbox()
        defer { elsewhere.remove() }
        let bundle = try elsewhere.app("Relay \(UUID().uuidString.prefix(8))", id: "com.example.relay")
        let support = try sandbox.file("Library/Application Support/Relay/data.db").deletingLastPathComponent()
        let relay = app("Relay", at: bundle, files: [support])
        let selection: Set<String> = [bundle.path, support.path]
        let plan = Uninstaller.plan(for: [relay], selection: selection)
        let safety = SafetyGuard(root: sandbox.root, allowedApplications: Uninstaller.bundles(in: [relay], selection: selection))

        let outcome = await Cleaner.run(plan: plan, safety: safety) { _ in }
        defer { outcome.trashed.forEach { try? FileManager.default.removeItem(at: $0.inTrash) } }
        #expect(outcome.failureCount == 0)
        #expect(outcome.cleanedItemIDs == selection)
        #expect(outcome.trashed.map(\.original) == [bundle, support])
        #expect(!Files.exists(bundle))
        #expect(!Files.exists(support))

        PutBack.save(outcome, home: sandbox.root)
        let pending = try #require(PutBack.pending(home: sandbox.root))
        #expect(PutBack.restore(pending, home: sandbox.root).isEmpty)
        #expect(Files.exists(bundle.appending(path: "Contents/Info.plist")))
        #expect(Files.exists(support.appending(path: "data.db")))
    }

    @Test func tellsARefusalByMacOSFromAnyOtherFailure() {
        let denied = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError)
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError,
                              userInfo: [NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(EPERM))])
        let missing = NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)
        #expect(Cleaner.isPermissionFailure(denied))
        #expect(Cleaner.isPermissionFailure(wrapped))
        #expect(!Cleaner.isPermissionFailure(missing))
    }

    @Test func asksFinderWithThePathQuoted() {
        let script = FinderTrash.script(for: "/Applications/My \"Best\" App.app")
        #expect(script.contains("POSIX file \"/Applications/My \\\"Best\\\" App.app\""))
        #expect(FinderTrash.reason(for: URL(fileURLWithPath: "/Applications/Relay.app"), error: "execution error: User canceled. (-128)")
            .contains("password prompt was cancelled"))
        #expect(FinderTrash.reason(for: URL(fileURLWithPath: "/Applications/Relay.app"), error: "Not authorized to send Apple events to Finder. (-1743)")
            .contains("Automation"))
    }
}

struct AppUpdateCheckerTests {
    private func app(version: String, build: String = "", feed: UpdateFeed? = .appStore) -> InstalledApp {
        InstalledApp(url: URL(fileURLWithPath: "/Applications/Relay.app"), name: "Relay", bundleID: "com.Example.Relay",
                     version: version, build: build, feed: feed)
    }

    @Test func comparesVersionsTheWayPeopleReadThem() {
        #expect(AppUpdateChecker.isNewer("12.10", than: "12.9"))
        #expect(!AppUpdateChecker.isNewer("12.9", than: "12.10"))
        #expect(!AppUpdateChecker.isNewer("14.4", than: "14.4"))
        #expect(!AppUpdateChecker.isNewer("14.4.0", than: "14.4"))
        #expect(AppUpdateChecker.isNewer("14.4.1", than: "14.4"))
        #expect(AppUpdateChecker.isNewer("v2.1.0", than: "2.0.2"))
        #expect(AppUpdateChecker.isNewer("2.0", than: "2.0b3"))
        #expect(!AppUpdateChecker.isNewer("2.0b3", than: "2.0"))
        #expect(AppUpdateChecker.isNewer("2.0b4", than: "2.0b3"))
        #expect(AppUpdateChecker.isNewer("7.1.9 (88375)", than: "7.1.9 (88001)"))
        #expect(AppUpdateChecker.isNewer("0.2026.10.01.08.29.01", than: "0.2026.09.30.08.29.01"))
        #expect(!AppUpdateChecker.isNewer("", than: "1.0"))
    }

    @Test func readsWhatTheAppStoreAnswers() throws {
        let json = """
        {"resultCount": 1, "results": [{"bundleId": "com.example.relay", "version": "12.10", "minimumOsVersion": "13.0",
          "currentVersionReleaseDate": "2026-08-29T13:50:18Z", "fileSizeBytes": "99361902",
          "releaseNotes": "- Small improvements and fixes.", "trackViewUrl": "https://apps.apple.com/kh/app/relay/id747648890?mt=12&uo=4"}]}
        """
        let entries = AppUpdateChecker.appStoreEntries(from: Data(json.utf8))
        let entry = try #require(entries["com.example.relay"])
        #expect(entry.size == 99_361_902)
        #expect(entry.page?.scheme == "macappstore")
        #expect(entry.page?.path == "/kh/app/relay/id747648890")

        let update = try #require(entry.update(for: app(version: "12.9"), systemVersion: "27.0.0"))
        #expect(update.installedVersion == "12.9")
        #expect(update.newVersion == "12.10")
        #expect(update.notes == "- Small improvements and fixes.")
        #expect(update.released == ISO8601DateFormatter().date(from: "2026-08-29T13:50:18Z"))
        #expect(entry.update(for: app(version: "12.10"), systemVersion: "27.0.0") == nil)
        // A version this Mac is too old to run is not an update for it.
        #expect(entry.update(for: app(version: "12.9"), systemVersion: "12.7.6") == nil)
        #expect(AppUpdateChecker.appStoreEntries(from: Data("not json".utf8)).isEmpty)

        let lookup = try #require(AppUpdateChecker.appStoreLookup(for: [app(version: "1")], region: "kh"))
        #expect(lookup.absoluteString.contains("bundleId=com.Example.Relay"))
        #expect(lookup.absoluteString.contains("country=kh"))
    }

    @Test func picksTheNewestReleaseThisMacCanRun() throws {
        let appcast = """
        <?xml version="1.0"?>
        <rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0"><channel>
          <item><title>Old</title><pubDate>Fri, 03 Apr 2020 17:10:16 +0300</pubDate>
            <enclosure url="https://example.com/a.zip" sparkle:version="465" sparkle:shortVersionString="2.2.20" length="40305523"/>
            <sparkle:maximumSystemVersion>10.10.999</sparkle:maximumSystemVersion></item>
          <item><title>Current</title><pubDate>Tue, 01 Sep 2026 09:00:00 +0000</pubDate>
            <sparkle:version>1210</sparkle:version><sparkle:shortVersionString>3.14.0</sparkle:shortVersionString>
            <description><![CDATA[<h2>What's new</h2><ul><li>Faster search</li><li>Fixes &amp; polish</li></ul>]]></description>
            <enclosure url="https://example.com/b.zip" length="54199859"/>
            <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion></item>
          <item><title>Beta</title><sparkle:channel>beta</sparkle:channel>
            <enclosure url="https://example.com/c.zip" sparkle:version="1300" sparkle:shortVersionString="4.0b1" length="1"/></item>
          <item><title>Needs a newer Mac</title>
            <enclosure url="https://example.com/d.zip" sparkle:version="1250" sparkle:shortVersionString="3.15.0" length="1"/>
            <sparkle:minimumSystemVersion>99.0</sparkle:minimumSystemVersion></item>
        </channel></rss>
        """
        let feed = UpdateFeed.sparkle(URL(string: "https://example.com/appcast.xml")!)
        let items = AppcastParser.items(in: Data(appcast.utf8))
        #expect(items.map(\.build) == ["465", "1210", "1300", "1250"])
        #expect(items[2].channel == "beta")

        let update = try #require(AppUpdateChecker.sparkleUpdate(for: app(version: "3.13.1", build: "1180", feed: feed),
                                                                 appcast: Data(appcast.utf8), systemVersion: "27.0.0"))
        #expect(update.newVersion == "3.14.0")
        #expect(update.installedVersion == "3.13.1")
        #expect(update.size == 54_199_859)
        #expect(update.notes == "What's new\n• Faster search\n• Fixes & polish")
        #expect(update.released != nil)
        #expect(update.feed == feed)
        // Builds are what a feed compares, so the same build is no update, whatever the version reads.
        #expect(AppUpdateChecker.sparkleUpdate(for: app(version: "3.13.1", build: "1210", feed: feed),
                                               appcast: Data(appcast.utf8), systemVersion: "27.0.0") == nil)
        #expect(AppUpdateChecker.sparkleUpdate(for: app(version: "1", build: "1", feed: feed),
                                               appcast: Data("<html>not a feed</html>".utf8), systemVersion: "27.0.0") == nil)
    }

    @Test func readsAnElectronManifest() throws {
        let manifest = """
        version: 2.1.0
        files:
          - url: Thing-2.1.0-arm64-mac.zip
            version: 9.9.9
            size: 123
        path: Thing-2.1.0-arm64-mac.zip
        releaseDate: '2026-08-30T10:11:12.000Z'
        """
        let feed = UpdateFeed.electron(URL(string: "https://example.com/latest-mac.yml")!)
        let update = try #require(AppUpdateChecker.electronUpdate(for: app(version: "2.0.2", feed: feed), manifest: manifest))
        #expect(update.newVersion == "2.1.0")
        #expect(update.released != nil)
        #expect(AppUpdateChecker.electronUpdate(for: app(version: "2.1.0", feed: feed), manifest: manifest) == nil)
        #expect(AppUpdateChecker.electronUpdate(for: app(version: "2.0.2", feed: feed), manifest: "<html></html>") == nil)
    }
}

@MainActor
struct AppsModelTests {
    private func model() -> AppsModel {
        AppsModel(home: URL(fileURLWithPath: "/Users/demo", isDirectory: true), settings: AppSettings())
    }

    @Test func filtersSearchesAndSortsTheApps() {
        let apps = model()
        apps.showDemo("manager")
        #expect(apps.count(for: .all) == apps.apps.count)
        #expect(apps.count(for: .unused) == 3)
        #expect(apps.count(for: .source(.appStore)) == 3)
        #expect(apps.count(for: .vendor(.jetBrains)) == 1)
        #expect(apps.sources == [.appStore, .other])
        #expect(apps.vendors.contains(.google) && apps.vendors.contains(.other))

        apps.filter = .unused
        #expect(Set(apps.visibleApps.map(\.name)) == ["Keyframe", "Pixel Forge", "Sprout VPN"])
        apps.filter = .all
        apps.sort = .size
        #expect(apps.visibleApps.first?.name == "Harbor")
        apps.sort = .name
        #expect(apps.visibleApps.map(\.name) == apps.visibleApps.map(\.name).sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        apps.search = "chrome"
        #expect(apps.visibleApps.map(\.name) == ["Google Chrome"])
        apps.search = "com.example.tally"
        #expect(apps.visibleApps.map(\.name) == ["Tally"])
    }

    @Test func tickingAnAppTicksEverythingItKeeps() throws {
        let apps = model()
        apps.showDemo("manager")
        apps.selectNone()
        let inkwell = try #require(apps.apps.first { $0.name == "Inkwell" })
        for binding in apps.bindings(for: inkwell.files) { binding.wrappedValue = true }
        #expect(apps.selectedAppCount == 1)
        #expect(apps.selectedAppSize == inkwell.size)
        #expect(apps.count(for: .selected) == 1)
        let plan = apps.plan
        #expect(plan.steps.map(\.title) == ["Inkwell"])
        #expect(plan.steps[0].operations.count == inkwell.files.count)

        // Unticking the app itself leaves a plan that only clears its files.
        apps.binding(for: try #require(inkwell.bundleFile)).wrappedValue = false
        #expect(apps.selectedAppCount == 0)
        #expect(apps.plan.steps.map(\.requiresFirst) == [false])
    }

    @Test func aFinishedUninstallDropsTheAppsThatWentAndKeepsTheOpenOne() {
        let apps = model()
        var reported: CleanOutcome?
        apps.didRemove = { reported = $0 }
        apps.showDemo("done")
        #expect(apps.phase == .done)
        #expect(apps.removal.isUninstall)
        #expect(apps.removal.apps == 2)
        #expect(apps.removal.items == 6)
        // Harbor was open, so it stays on the list and stays ticked.
        #expect(apps.apps.contains { $0.name == "Harbor" })
        #expect(!apps.apps.contains { $0.name == "Keyframe" || $0.name == "Tally" })
        #expect(!apps.updates.contains { $0.id.contains("Tally") })
        #expect(apps.selectedAppCount == 1)
        #expect(reported?.trashed.count == 6)
        apps.manageMore()
        #expect(apps.phase == .managing)
    }

    @Test func leftoversAreRemovedThroughTheirOwnPlan() {
        let apps = model()
        apps.showDemo("leftovers")
        #expect(apps.removesLeftovers)
        #expect(apps.selectedLeftoverCount == 2)
        #expect(apps.selectedLeftoverSize == 783_000_000)
        #expect(apps.plan.steps.map(\.id) == [AppsModel.installersFindingID])
        #expect(apps.blockedSteps(in: apps.plan).isEmpty)
        #expect(!apps.needsPassword)
        apps.selectNone()
        #expect(apps.plan.isEmpty)
    }
}
