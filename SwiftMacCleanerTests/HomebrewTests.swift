//
//  HomebrewTests.swift
//  SwiftMacCleanerTests
//
//  Apps Homebrew installed: which they are, when Homebrew has something newer for one, and what
//  happens when it is asked to install it. Homebrew itself is never run here.
//

import Foundation
import Testing
@testable import SwiftMacCleaner

/// A throwaway folder with an Applications folder and a Caskroom in it.
private struct Brewery {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "mdc-brew-\(UUID().uuidString)").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: caskroom, withIntermediateDirectories: true)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    var caskroom: URL { root.appending(path: "Caskroom") }
    var applications: URL { root.appending(path: "Applications") }

    /// An app bundle with a version of its own.
    @discardableResult
    func app(_ name: String, id: String, version: String) throws -> URL {
        let bundle = applications.appending(path: "\(name).app")
        try FileManager.default.createDirectory(at: bundle.appending(path: "Contents/MacOS"), withIntermediateDirectories: true)
        let info: [String: Any] = ["CFBundleIdentifier": id, "CFBundleName": name, "CFBundleExecutable": name,
                                   "CFBundleShortVersionString": version, "CFBundleVersion": version]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: bundle.appending(path: "Contents/Info.plist"))
        try Data(repeating: 1, count: 2_048).write(to: bundle.appending(path: "Contents/MacOS/\(name)"))
        return bundle
    }

    /// A cask as Homebrew leaves it: a folder for the version with a link to the app, and a record of where it came from.
    func cask(_ token: String, version: String, linkedTo app: URL?, tap: String? = HomebrewCasks.officialTap) throws {
        let folder = caskroom.appending(path: "\(token)/\(version)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let app {
            try FileManager.default.createSymbolicLink(at: folder.appending(path: app.lastPathComponent), withDestinationURL: app)
        }
        if let tap {
            let metadata = caskroom.appending(path: "\(token)/.metadata")
            try FileManager.default.createDirectory(at: metadata, withIntermediateDirectories: true)
            let receipt: [String: Any] = ["source": ["tap": tap, "version": version]]
            try JSONSerialization.data(withJSONObject: receipt).write(to: metadata.appending(path: "INSTALL_RECEIPT.json"))
        }
    }
}

private func app(_ name: String, version: String, cask: InstalledCask? = nil, feed: UpdateFeed? = nil) -> InstalledApp {
    InstalledApp(url: URL(fileURLWithPath: "/Applications/\(name).app"), name: name, bundleID: "com.example.\(name.lowercased())",
                 version: version, build: version, feed: feed, cask: cask)
}

private func cask(_ token: String, _ version: String, official: Bool = true) -> InstalledCask {
    InstalledCask(token: token, version: version, app: URL(fileURLWithPath: "/Applications/\(token).app"), isOfficial: official)
}

struct HomebrewCasksTests {
    @Test func readsWhichAppsHomebrewInstalledFromItsCaskroom() async throws {
        let brewery = try Brewery()
        defer { brewery.remove() }
        let relay = try brewery.app("Relay", id: "com.example.relay", version: "9.42.2")
        let tally = try brewery.app("Tally", id: "com.example.tally", version: "14.4")
        let plain = try brewery.app("Plain", id: "com.example.plain", version: "1.0")
        try brewery.cask("relay", version: "9.42.2,881", linkedTo: relay)
        try brewery.cask("tally", version: "14.4", linkedTo: tally, tap: "maker/tools")
        // Kept no record of where it came from, as older versions of Homebrew did.
        try brewery.cask("plain", version: "1.0", linkedTo: plain, tap: nil)
        // Installed something other than an app, lost its app since, or is no cask at all.
        try brewery.cask("ngrok", version: "3.30.0", linkedTo: nil)
        try brewery.cask("gone", version: "2.0", linkedTo: brewery.applications.appending(path: "Gone.app"))
        try brewery.cask("Not A Cask", version: "1.0", linkedTo: relay)

        let casks = HomebrewCasks.installed(in: [brewery.caskroom, brewery.root.appending(path: "missing")])
        #expect(casks.map(\.token).sorted() == ["plain", "relay", "tally"])
        let found = Dictionary(uniqueKeysWithValues: casks.map { ($0.token, $0) })
        #expect(found["relay"]?.version == "9.42.2,881")
        #expect(found["relay"]?.app.path == relay.path)
        #expect(found["relay"]?.isOfficial == true)
        #expect(found["tally"]?.isOfficial == false)
        #expect(found["plain"]?.isOfficial == true)
        #expect(found["plain"]?.version == "1.0")

        // The scan hands each app the cask that installed it.
        let apps = await AppScanner.scan(home: brewery.root, roots: [brewery.applications], safety: SafetyGuard(root: brewery.root),
                                         systemFolders: [], caskrooms: [brewery.caskroom]) { _ in }
        #expect(apps.first { $0.name == "Relay" }?.cask?.token == "relay")
        #expect(apps.first { $0.name == "Tally" }?.cask?.isOfficial == false)
        #expect(apps.count == 3)
    }

    @Test func tellsACasksNameFromAnythingElse() {
        for token in ["google-chrome", "visual-studio-code", "font-fira-code", "1password", "docker-desktop@beta", "c++", "a.b_c"] {
            #expect(HomebrewCasks.isValid(token: token), "\(token)")
        }
        for token in ["", "Google Chrome", "-rf", "../etc", "relay;rm", "UPPER", "a/b", "relay cask", String(repeating: "a", count: 200)] {
            #expect(!HomebrewCasks.isValid(token: token), "\(token)")
        }
        #expect(HomebrewCasks.lookup(for: "google-chrome")?.absoluteString == "https://formulae.brew.sh/api/cask/google-chrome.json")
        #expect(HomebrewCasks.lookup(for: "../../secret") == nil)
        #expect(HomebrewCasks.upgradeArguments(for: "relay") == ["upgrade", "--cask", "--", "relay"])
        #expect(HomebrewCasks.upgradeArguments(for: "--force") == nil)
    }

    @Test func readsWhatTheCatalogueSaysAboutACask() throws {
        let answer = Data(#"{"token":"relay","version":"9.43.0,902","auto_updates":true,"disabled":false,"bundle_short_version":"9.40"}"#.utf8)
        #expect(HomebrewCasks.release(from: answer) == CaskRelease(version: "9.43.0,902", isDisabled: false))
        #expect(HomebrewCasks.release(from: Data(#"{"version":"2.0","disabled":true}"#.utf8))?.isDisabled == true)
        // A cask the catalogue does not have answers with a page, not with this.
        #expect(HomebrewCasks.release(from: Data("<html>Not Found</html>".utf8)) == nil)
        #expect(HomebrewCasks.release(from: Data(#"{"token":"relay"}"#.utf8)) == nil)
        #expect(HomebrewCasks.appVersion(of: "9.43.0,902") == "9.43.0")
        #expect(HomebrewCasks.appVersion(of: "3.30.0,hccQ4GWLNHr,a") == "3.30.0")
        #expect(HomebrewCasks.appVersion(of: "141.0.7390.55") == "141.0.7390.55")
    }

    @Test func offersAnUpdateOnlyWhenTheAppItselfIsBehind() throws {
        let installed = cask("relay", "9.42.2,881")
        let relay = app("Relay", version: "9.42.2", cask: installed)

        let update = try #require(HomebrewCasks.update(for: relay, cask: installed, release: CaskRelease(version: "9.43.0,902")))
        #expect(update.id == relay.id)
        #expect(update.installedVersion == "9.42.2")
        #expect(update.newVersion == "9.43.0")
        #expect(update.cask == "relay")
        #expect(update.feed == .homebrew)
        #expect(update.source == "Homebrew")

        // Where Homebrew left it: nothing to do, however the two version numbers compare.
        #expect(HomebrewCasks.update(for: relay, cask: installed, release: CaskRelease(version: "9.42.2,881")) == nil)
        // The app has updated itself past what Homebrew recorded, and is already where the cask is now.
        let ahead = app("Relay", version: "9.43.0", cask: installed)
        #expect(HomebrewCasks.update(for: ahead, cask: installed, release: CaskRelease(version: "9.43.0,902")) == nil)
        // No version to compare, or no longer installed by Homebrew at all.
        #expect(HomebrewCasks.update(for: relay, cask: installed, release: CaskRelease(version: "latest")) == nil)
        #expect(HomebrewCasks.update(for: relay, cask: installed, release: CaskRelease(version: "9.43.0", isDisabled: true)) == nil)
        // An app that says no version of its own is compared by the cask's.
        let silent = app("Relay", version: "", cask: installed)
        #expect(HomebrewCasks.update(for: silent, cask: installed, release: CaskRelease(version: "9.43.0,902"))?.installedVersion == "9.42.2")
    }

    @Test func anUpdateHomebrewHasIsTheOneOfferedWithWhatTheAppsOwnFeedSaid() {
        let feed = UpdateFeed.sparkle(URL(fileURLWithPath: "/dev/null"))
        let released = Date(timeIntervalSince1970: 1_800_000_000)
        let fromFeed = AppUpdate(id: "relay", installedVersion: "9.42.2", newVersion: "9.44.0", released: released, size: 400,
                                 notes: "Faster", feed: feed, storeURL: nil)
        let fromHomebrew = AppUpdate(id: "relay", installedVersion: "9.42.2", newVersion: "9.43.0", feed: .homebrew, cask: "relay")
        let other = AppUpdate(id: "tally", installedVersion: "1", newVersion: "2", feed: .appStore)
        let onlyHomebrew = AppUpdate(id: "inkwell", installedVersion: "3", newVersion: "4", feed: .homebrew, cask: "inkwell")

        let merged = AppUpdateChecker.merged(feeds: ["relay": fromFeed, "tally": other],
                                             homebrew: ["relay": fromHomebrew, "inkwell": onlyHomebrew],
                                             order: ["tally", "harbor", "relay", "inkwell"])
        #expect(merged.map(\.id) == ["tally", "relay", "inkwell"])
        let relay = merged[1]
        // What gets installed is what Homebrew has, which may be a step behind the app's own feed.
        #expect(relay.cask == "relay")
        #expect(relay.newVersion == "9.43.0")
        #expect(relay.released == released)
        #expect(relay.notes == "Faster")
        #expect(relay.feed == feed)
        #expect(relay.source == "Homebrew")
        #expect(merged[0].source == "App Store")
        #expect(merged[2].feed == .homebrew)
    }

    @Test func saysWhatWentWrongInASentence() {
        func failure(_ stderr: String, stdout: String = "", timedOut: Bool = false, cancelled: Bool = false) -> String {
            HomebrewCasks.failure(from: Shell.Output(status: 1, stdout: stdout, stderr: stderr, timedOut: timedOut, cancelled: cancelled), token: "relay")
        }
        #expect(failure("==> Upgrading relay\nError: Download failed on Cask 'relay' with message: Timeout\n")
            == "Homebrew did not install it: Download failed on Cask 'relay' with message: Timeout")
        // Some casks need the system's installer, and that needs a password this app does not ask for.
        #expect(failure("sudo: a terminal is required to read the password; either use the -S option\nError: Failure while executing")
            == "Homebrew needs your password for this one. Run “brew upgrade --cask relay” in Terminal.")
        #expect(failure("", stdout: "Warning: something odd") == "Homebrew did not install it: Warning: something odd")
        #expect(failure("") == "Homebrew did not install it: it gave no reason")
        #expect(failure("", timedOut: true).contains("within an hour"))
        #expect(failure("", cancelled: true).contains("stopped"))
        // Homebrew is asked to say nothing home, and gets the usual places to find its tools.
        let environment = HomebrewCasks.environment(from: ["HOME": "/Users/demo", "PATH": "/nowhere"])
        #expect(environment["HOMEBREW_NO_ANALYTICS"] == "1")
        #expect(environment["HOME"] == "/Users/demo")
        #expect(environment["PATH"]?.contains("/opt/homebrew/bin") == true)
    }

    @Test func asksHomebrewForOneCaskAndReadsHowItWent() throws {
        let brewery = try Brewery()
        defer { brewery.remove() }
        // A stand-in for `brew` that writes down what it was asked, and fails for one cask.
        let asked = brewery.root.appending(path: "asked.txt")
        let brew = brewery.root.appending(path: "brew")
        let script = """
        #!/bin/sh
        echo "$@ analytics=$HOMEBREW_NO_ANALYTICS" >> '\(asked.path)'
        if [ "$4" = "broken" ]; then echo "Error: broken: the download did not match" >&2; exit 1; fi
        echo "==> Upgrading $4"
        """
        try Data(script.utf8).write(to: brew)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: brew.path)

        #expect(HomebrewCasks.upgrade(token: "relay", brew: brew.path) == .done)
        #expect(HomebrewCasks.upgrade(token: "broken", brew: brew.path)
            == .failed("Homebrew did not install it: broken: the download did not match"))
        // A name no cask has never reaches Homebrew, and a Homebrew that is not there says so.
        #expect(HomebrewCasks.upgrade(token: "--force", brew: brew.path) == .failed("“--force” is not a name Homebrew gives a cask."))
        #expect(HomebrewCasks.upgrade(token: "relay", brew: brewery.root.appending(path: "missing").path) == .failed("Homebrew could not be started."))
        let lines = try String(contentsOf: asked, encoding: .utf8).split(separator: "\n").map(String.init)
        #expect(lines == ["upgrade --cask -- relay analytics=1", "upgrade --cask -- broken analytics=1"])
        #expect(HomebrewCasks.brew(prefixes: [brewery.root.appending(path: "none").path]) == nil)
    }
}

@MainActor
struct HomebrewInstallTests {
    /// The model on the made-up apps, with a stand-in for Homebrew that notes what it was asked.
    private func model(answering: @escaping @Sendable (String) -> HomebrewCasks.UpgradeResult) -> (AppsModel, Asked) {
        let apps = AppsModel(home: URL(fileURLWithPath: "/Users/demo", isDirectory: true), settings: AppSettings())
        apps.showDemo("updater")
        let asked = Asked()
        apps.upgradeCask = { token in
            asked.note(token)
            return answering(token)
        }
        return (apps, asked)
    }

    private func finished(_ apps: AppsModel) async throws {
        for _ in 0..<200 where !apps.installing.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
    }

    @Test func onlyAnAppHomebrewInstalledIsUpdatedFromHere() throws {
        let (apps, _) = model { _ in .done }
        let relay = try #require(apps.updates.first { $0.cask != nil })
        #expect(apps.app(withID: relay.id)?.name == "Relay")
        #expect(apps.canInstall(relay))
        #expect(apps.installableUpdates.map(\.id) == [relay.id])
        #expect(apps.updates.filter { !apps.canInstall($0) }.count == apps.updates.count - 1)
        // Without Homebrew on the Mac, nothing is offered through it.
        apps.upgradeCask = nil
        #expect(!apps.canInstall(relay))
        #expect(apps.installableUpdates.isEmpty)
    }

    @Test func aFinishedUpdateLeavesTheListAndAFailedOneSaysWhy() async throws {
        let (apps, asked) = model { _ in .done }
        let relay = try #require(apps.updates.first { $0.cask != nil })
        let before = apps.updates.count

        apps.install([relay])
        #expect(apps.installing == [relay.id])
        // Asked for twice while it runs, it is still installed once.
        apps.install([relay])
        try await finished(apps)
        #expect(asked.tokens == ["relay"])
        #expect(apps.updates.count == before - 1)
        #expect(!apps.updates.contains { $0.id == relay.id })
        #expect(apps.installFailures.isEmpty)
        #expect(apps.installingNow == nil)

        let (failing, _) = model { _ in .failed("Homebrew did not install it: no network") }
        let again = try #require(failing.updates.first { $0.cask != nil })
        failing.install([again])
        try await finished(failing)
        #expect(failing.updates.contains { $0.id == again.id })
        #expect(failing.installFailures[again.id] == "Homebrew did not install it: no network")
        // Trying again clears the message while it runs.
        failing.upgradeCask = { _ in .done }
        failing.install([again])
        #expect(failing.installFailures[again.id] == nil)
        try await finished(failing)
        #expect(!failing.updates.contains { $0.id == again.id })
    }

    @Test func anAppThatIsOpenIsNotReplacedUnderneathItself() async throws {
        let (apps, asked) = model { _ in .done }
        let relay = try #require(apps.updates.first { $0.cask != nil })
        apps.isAppRunning = { $0 == "com.example.relay" }
        apps.install([relay])
        try await finished(apps)
        #expect(asked.tokens.isEmpty)
        #expect(apps.installFailures[relay.id] == "Relay is open. Quit it, then update again.")
        #expect(apps.updates.contains { $0.id == relay.id })
    }

    @Test func aScanWaitsWhileHomebrewIsReplacingAnApp() async throws {
        let (apps, _) = model { _ in
            Thread.sleep(forTimeInterval: 0.2)
            return .done
        }
        let relay = try #require(apps.updates.first { $0.cask != nil })
        var scans = 0
        apps.didScan = { scans += 1 }
        apps.install([relay])
        apps.startScan()
        // The list is left as it is, and whoever asked for the scan is told it is over.
        #expect(apps.phase == .managing)
        #expect(scans == 1)
        #expect(!apps.apps.isEmpty)
        try await finished(apps)
    }
}

/// What the stand-in for Homebrew was asked to upgrade, in order.
private final class Asked: @unchecked Sendable {
    private let lock = NSLock()
    private var asked: [String] = []

    func note(_ token: String) {
        lock.lock()
        asked.append(token)
        lock.unlock()
    }

    var tokens: [String] {
        lock.lock()
        defer { lock.unlock() }
        return asked
    }
}
