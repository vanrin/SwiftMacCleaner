//
//  AppSettings.swift
//  Mac Disk Cleaner
//

import Foundation
import Observation

@Observable
final class AppSettings {
    static let staleChoices = [30, 60, 90, 180]

    /// How long a project must sit untouched before its build folders are offered.
    var staleDays: Int {
        didSet { UserDefaults.standard.set(staleDays, forKey: "staleDays") }
    }

    /// Folders that hold the user's projects.
    var projectRoots: [String] {
        didSet { UserDefaults.standard.set(projectRoots, forKey: "projectRoots") }
    }

    init() {
        let defaults = UserDefaults.standard
        let storedDays = defaults.integer(forKey: "staleDays")
        staleDays = Self.staleChoices.contains(storedDays) ? storedDays : 60
        projectRoots = defaults.stringArray(forKey: "projectRoots") ?? Self.detectedRoots()
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

    func scanContext() -> ScanContext {
        ScanContext(
            home: FileManager.default.homeDirectoryForCurrentUser,
            staleDays: staleDays,
            projectRoots: projectRoots.map { URL(fileURLWithPath: $0, isDirectory: true) }
        )
    }
}
