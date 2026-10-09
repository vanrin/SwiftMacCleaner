//
//  AppSettings.swift
//  SwiftMacCleaner
//

import Foundation
import Observation

/// One path the user asked never to see again.
nonisolated struct NeverSuggestEntry: Codable, Identifiable, Hashable, Sendable {
    var path: String
    var title: String
    var added: Date

    var id: String { path }
}

@Observable
final class AppSettings {
    static let staleChoices = [30, 60, 90, 180]
    static let largeFileChoices = [30, 90, 180, 365]

    /// How long a project must sit untouched before its build folders are offered.
    var staleDays: Int {
        didSet { defaults.set(staleDays, forKey: "staleDays") }
    }

    /// How long a large file in Downloads must sit untouched before it is offered.
    var largeFileDays: Int {
        didSet { defaults.set(largeFileDays, forKey: "largeFileDays") }
    }

    /// Folders that hold the user's projects.
    var projectRoots: [String] {
        didSet { defaults.set(projectRoots, forKey: "projectRoots") }
    }

    /// Paths that are never offered again.
    var neverSuggest: [NeverSuggestEntry] {
        didSet { defaults.set(try? JSONEncoder().encode(neverSuggest), forKey: "neverSuggest") }
    }

    /// Whether Xcode versions other than the selected one may be offered from /Applications.
    var offersOldXcodes: Bool {
        didSet { defaults.set(offersOldXcodes, forKey: "offersOldXcodes") }
    }

    /// Whether the one step that needs a password (local snapshots) is offered at all.
    var offersSnapshots: Bool {
        didSet { defaults.set(offersSnapshots, forKey: "offersSnapshots") }
    }

    /// Whether a look at the installed apps also asks their update feeds which version is current.
    var checksAppUpdates: Bool {
        didSet { defaults.set(checksAppUpdates, forKey: "checksAppUpdates") }
    }

    /// Whether the disk status item sits in the menu bar.
    var showsMenuBarItem: Bool {
        didSet { defaults.set(showsMenuBarItem, forKey: "showsMenuBarItem") }
    }

    /// Whether the app scans on its own once a week and says what it found. Nothing is ever removed by it.
    var weeklyCheck: Bool {
        didSet { defaults.set(weeklyCheck, forKey: "weeklyCheck") }
    }

    /// When the last scan finished, for the menu bar and the weekly check.
    var lastScanDate: Date? {
        didSet { defaults.set(lastScanDate, forKey: "lastScanDate") }
    }

    /// When each maintenance task last ran, by its name, which decides which are recommended again.
    var maintenanceRuns: [String: Date] {
        didSet { defaults.set(maintenanceRuns, forKey: "maintenanceRuns") }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showsMenuBarItem = defaults.object(forKey: "showsMenuBarItem") as? Bool ?? true
        weeklyCheck = defaults.object(forKey: "weeklyCheck") as? Bool ?? true
        lastScanDate = defaults.object(forKey: "lastScanDate") as? Date
        maintenanceRuns = defaults.dictionary(forKey: "maintenanceRuns") as? [String: Date] ?? [:]
        let storedDays = defaults.integer(forKey: "staleDays")
        staleDays = Self.staleChoices.contains(storedDays) ? storedDays : 60
        let storedLarge = defaults.integer(forKey: "largeFileDays")
        largeFileDays = Self.largeFileChoices.contains(storedLarge) ? storedLarge : 90
        projectRoots = defaults.stringArray(forKey: "projectRoots") ?? Self.detectedRoots()
        neverSuggest = defaults.data(forKey: "neverSuggest").flatMap { try? JSONDecoder().decode([NeverSuggestEntry].self, from: $0) } ?? []
        offersOldXcodes = defaults.object(forKey: "offersOldXcodes") as? Bool ?? true
        offersSnapshots = defaults.object(forKey: "offersSnapshots") as? Bool ?? true
        checksAppUpdates = defaults.object(forKey: "checksAppUpdates") as? Bool ?? true
    }

    /// Common places people keep code. Documents and Desktop are left for the user to add,
    /// because looking there raises a permission prompt.
    nonisolated static func detectedRoots() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let names = [
            "Code", "Developer", "Projects", "dev", "src", "workspace", "repos", "git", "Sites",
            "StudioProjects", "AndroidStudioProjects", "IdeaProjects", "XcodeProjects",
        ]
        return names.map { home.appending(path: $0) }.filter(Files.isDirectory).map(\.path)
    }

    func addNeverSuggest(path: String, title: String) {
        guard !neverSuggest.contains(where: { $0.path == path }) else { return }
        neverSuggest.append(NeverSuggestEntry(path: path, title: title, added: Date()))
    }

    /// The last run of each maintenance task.
    var lastMaintenanceRuns: [MaintenanceTask: Date] {
        Dictionary(uniqueKeysWithValues: maintenanceRuns.compactMap { name, date in MaintenanceTask(rawValue: name).map { ($0, date) } })
    }

    func recordMaintenanceRun(of tasks: [MaintenanceTask], at date: Date = Date()) {
        for task in tasks { maintenanceRuns[task.rawValue] = date }
    }

    func removeNeverSuggest(_ entry: NeverSuggestEntry) {
        neverSuggest.removeAll { $0.path == entry.path }
    }

    func scanContext(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> ScanContext {
        ScanContext(
            home: home,
            staleDays: staleDays,
            largeFileDays: largeFileDays,
            projectRoots: projectRoots.map { URL(fileURLWithPath: $0, isDirectory: true) },
            excluded: neverSuggest.map(\.path)
        )
    }
}

/// Where the guard may reach outside the home folder.
nonisolated enum GuardRoots {
    /// The per-user cache and temp folders under /var/folders, which belong to this user alone.
    static func userTemporaryFolders() -> [URL] {
        [_CS_DARWIN_USER_CACHE_DIR, _CS_DARWIN_USER_TEMP_DIR].compactMap { name in
            var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
            guard confstr(name, &buffer, buffer.count) > 0 else { return nil }
            let path = String(cString: buffer)
            return path.isEmpty ? nil : URL(fileURLWithPath: path, isDirectory: true)
        }
    }

    /// The Xcode `xcode-select` points at, which is never offered.
    static func selectedXcode() -> URL? {
        guard let output = Shell.run("/usr/bin/xcode-select", ["-p"], timeout: 10), output.succeeded else { return nil }
        let developer = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard developer.hasSuffix("/Contents/Developer") else { return nil }
        return URL(fileURLWithPath: String(developer.dropLast("/Contents/Developer".count)), isDirectory: true)
    }

    /// Xcode bundles in /Applications other than the selected one. When no Xcode is selected, for
    /// example because xcode-select points at the Command Line Tools, nothing is offered at all.
    static func otherXcodes() -> [URL] {
        guard let selected = selectedXcode()?.standardizedFileURL.path else { return [] }
        return Files.children(of: URL(fileURLWithPath: "/Applications", isDirectory: true))
            .filter { $0.lastPathComponent.hasPrefix("Xcode") && $0.pathExtension == "app" && !Files.isSymlink($0) }
            .filter { Files.isDirectory($0.appending(path: "Contents/Developer")) }
            .filter { $0.standardizedFileURL.path != selected }
    }
}
