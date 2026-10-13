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
    /// How big a file may have to be to count as large, in megabytes.
    static let largeFileSizeChoices = [50, 100, 500, 1_000]

    /// How long a project must sit untouched before its build folders are offered.
    var staleDays: Int {
        didSet { defaults.set(staleDays, forKey: "staleDays") }
    }

    /// How long a large file in Downloads, Documents or Desktop must sit untouched before it is offered.
    var largeFileDays: Int {
        didSet { defaults.set(largeFileDays, forKey: "largeFileDays") }
    }

    /// How big, in megabytes, a file has to be to be offered as a large one.
    var largeFileMegabytes: Int {
        didSet { defaults.set(largeFileMegabytes, forKey: "largeFileMegabytes") }
    }

    /// Folders that hold the user's projects.
    var projectRoots: [String] {
        didSet { defaults.set(projectRoots, forKey: "projectRoots") }
    }

    /// Paths that are never offered again.
    var neverSuggest: [NeverSuggestEntry] {
        didSet { defaults.set(try? JSONEncoder().encode(neverSuggest), forKey: "neverSuggest") }
    }

    /// The protection checks the user said to leave as they are, by name. One that is off stops
    /// counting among what needs a look, and is still listed.
    var acceptedProtection: [String] {
        didSet { defaults.set(acceptedProtection, forKey: "acceptedProtection") }
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

    /// Whether the app's item sits in the menu bar.
    var showsMenuBarItem: Bool {
        didSet { defaults.set(showsMenuBarItem, forKey: "showsMenuBarItem") }
    }

    /// Whether the processor's load is written beside the icon in the menu bar. Off unless asked
    /// for: it is the one thing that has the app read the Mac while nothing of it is open.
    var showsCPUBesideIcon: Bool {
        didSet { defaults.set(showsCPUBesideIcon, forKey: "showsCPUBesideIcon") }
    }

    /// Whether memory pressure is written beside the icon in the menu bar.
    var showsMemoryBesideIcon: Bool {
        didSet { defaults.set(showsMemoryBesideIcon, forKey: "showsMemoryBesideIcon") }
    }

    /// Whether the sidebar is folded down to a rail of glyphs, with the names left out.
    var isSidebarCollapsed: Bool {
        didSet { defaults.set(isSidebarCollapsed, forKey: "sidebarCollapsed") }
    }

    /// The kinds of thing Smart selection ticks after a scan.
    var smartKinds: Set<SmartKind> {
        didSet { defaults.set(smartKinds.map(\.rawValue).sorted(), forKey: "smartKinds") }
    }

    /// Whether the app scans on its own once a week and says what it found.
    var weeklyCheck: Bool {
        didSet { defaults.set(weeklyCheck, forKey: "weeklyCheck") }
    }

    /// Whether the weekly check goes on to clean the Smart selection by itself. Off unless asked for:
    /// it is the one place the app removes anything without the confirmation.
    var weeklyCheckCleans: Bool {
        didSet { defaults.set(weeklyCheckCleans, forKey: "weeklyCheckCleans") }
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
        showsCPUBesideIcon = defaults.bool(forKey: "showsCPUBesideIcon")
        showsMemoryBesideIcon = defaults.bool(forKey: "showsMemoryBesideIcon")
        isSidebarCollapsed = defaults.bool(forKey: "sidebarCollapsed")
        smartKinds = SmartKind.stored(forKey: "smartKinds", in: defaults)
        weeklyCheck = defaults.object(forKey: "weeklyCheck") as? Bool ?? true
        weeklyCheckCleans = defaults.bool(forKey: "weeklyCheckCleans")
        lastScanDate = defaults.object(forKey: "lastScanDate") as? Date
        maintenanceRuns = defaults.dictionary(forKey: "maintenanceRuns") as? [String: Date] ?? [:]
        let storedDays = defaults.integer(forKey: "staleDays")
        staleDays = Self.staleChoices.contains(storedDays) ? storedDays : 60
        let storedLarge = defaults.integer(forKey: "largeFileDays")
        largeFileDays = Self.largeFileChoices.contains(storedLarge) ? storedLarge : 90
        let storedSize = defaults.integer(forKey: "largeFileMegabytes")
        largeFileMegabytes = Self.largeFileSizeChoices.contains(storedSize) ? storedSize : 100
        projectRoots = defaults.stringArray(forKey: "projectRoots") ?? Self.detectedRoots()
        neverSuggest = defaults.data(forKey: "neverSuggest").flatMap { try? JSONDecoder().decode([NeverSuggestEntry].self, from: $0) } ?? []
        acceptedProtection = defaults.stringArray(forKey: "acceptedProtection") ?? []
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

    /// Folds the sidebar down to its glyphs, or opens it out again.
    func toggleSidebar() {
        isSidebarCollapsed.toggle()
    }

    func scanContext(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> ScanContext {
        ScanContext(
            home: home,
            staleDays: staleDays,
            largeFileDays: largeFileDays,
            largeFileSize: Int64(largeFileMegabytes) * 1_000_000,
            projectRoots: projectRoots.map { URL(fileURLWithPath: $0, isDirectory: true) },
            excluded: neverSuggest.map(\.path),
            systemLogRoots: SystemLogs.roots
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

    /// The temp folder every program on the Mac shares. macOS empties it at each restart, and a
    /// user can remove only what is their own from it.
    static let sharedTemporaryFolder = URL(fileURLWithPath: "/private/tmp", isDirectory: true)

    /// Every temp folder the guard lets a clean-up reach into.
    static func temporaryFolders() -> [URL] { userTemporaryFolders() + [sharedTemporaryFolder] }

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
