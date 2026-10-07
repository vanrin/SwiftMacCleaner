//
//  AppSettings.swift
//  Mac Disk Cleaner
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

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedDays = defaults.integer(forKey: "staleDays")
        staleDays = Self.staleChoices.contains(storedDays) ? storedDays : 60
        let storedLarge = defaults.integer(forKey: "largeFileDays")
        largeFileDays = Self.largeFileChoices.contains(storedLarge) ? storedLarge : 90
        projectRoots = defaults.stringArray(forKey: "projectRoots") ?? Self.detectedRoots()
        neverSuggest = defaults.data(forKey: "neverSuggest").flatMap { try? JSONDecoder().decode([NeverSuggestEntry].self, from: $0) } ?? []
        offersOldXcodes = defaults.object(forKey: "offersOldXcodes") as? Bool ?? true
        offersSnapshots = defaults.object(forKey: "offersSnapshots") as? Bool ?? true
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

    /// Xcode bundles in /Applications other than the selected one.
    static func otherXcodes() -> [URL] {
        let selected = selectedXcode()?.standardizedFileURL.path
        return Files.children(of: URL(fileURLWithPath: "/Applications", isDirectory: true))
            .filter { $0.lastPathComponent.hasPrefix("Xcode") && $0.pathExtension == "app" && !Files.isSymlink($0) }
            .filter { Files.isDirectory($0.appending(path: "Contents/Developer")) }
            .filter { $0.standardizedFileURL.path != selected }
    }
}
