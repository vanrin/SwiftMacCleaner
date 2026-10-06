//
//  Models.swift
//  Mac Disk Cleaner
//

import Foundation

/// A part of the disk the app knows how to look at.
nonisolated enum Area: String, CaseIterable, Identifiable, Sendable {
    case xcode, projects, android, docker, packageCaches, toolchains, cachesLogs, installersTrash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .xcode: "Xcode"
        case .projects: "Projects"
        case .android: "Android and Gradle"
        case .docker: "Docker"
        case .packageCaches: "Package caches"
        case .toolchains: "Toolchains"
        case .cachesLogs: "Caches and logs"
        case .installersTrash: "Installers and Trash"
        }
    }

    var summary: String {
        switch self {
        case .xcode: "DerivedData, device support, simulators, archives"
        case .projects: "node_modules, Pods and build folders in stale projects"
        case .android: "~/.gradle, emulators, SDK system images"
        case .docker: "Unused images, stopped containers, build cache"
        case .packageCaches: "npm, pnpm, Yarn, CocoaPods, pub, Homebrew and more"
        case .toolchains: "Old JDKs, Node versions and SDKs"
        case .cachesLogs: "~/Library/Caches and ~/Library/Logs"
        case .installersTrash: "Disk images in Downloads, items in the Trash"
        }
    }

    var symbol: String {
        switch self {
        case .xcode: "hammer"
        case .projects: "folder"
        case .android: "iphone"
        case .docker: "shippingbox"
        case .packageCaches: "archivebox"
        case .toolchains: "terminal"
        case .cachesLogs: "doc.text"
        case .installersTrash: "trash"
        }
    }

    var isDeveloper: Bool {
        switch self {
        case .cachesLogs, .installersTrash: false
        default: true
        }
    }
}

/// How much thought removing something deserves.
nonisolated enum SafetyTier: Int, CaseIterable, Comparable, Sendable {
    case safe, review, careful

    static func < (lhs: SafetyTier, rhs: SafetyTier) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .safe: "Safe"
        case .review: "Review"
        case .careful: "Careful"
        }
    }

    var headline: String {
        switch self {
        case .safe: "Rebuilds itself"
        case .review: "Needs a re-download"
        case .careful: "Cannot be recreated"
        }
    }

    var explanation: String {
        switch self {
        case .safe: "Caches and build output. Your tools recreate them the next time they run."
        case .review: "Removable, but you would have to fetch or set these up again."
        case .careful: "Never selected for you. Remove only if you are sure."
        }
    }
}

/// How a finding is removed.
nonisolated enum CleanMethod: Sendable, Hashable {
    /// Removed for good, right away.
    case delete
    /// Moved to the Trash, so space comes back once the Trash is emptied.
    case trash
    /// Handed to the tool that owns the data, such as `docker` or `xcrun simctl`.
    case command

    var verb: String {
        switch self {
        case .delete: "Deletes"
        case .trash: "Moves to Trash"
        case .command: "Runs"
        }
    }
}

/// One thing that can be ticked: a folder, a set of folders, or a command to run.
nonisolated struct FindingItem: Identifiable, Sendable, Hashable {
    let id: String
    var title: String
    var detail: String
    var size: Int64
    var paths: [URL] = []
    var command: [String]? = nil
    /// Overrides the tier default. `nil` means "ticked only when the finding is safe".
    var preselected: Bool? = nil
    /// Shown in monospace under the detail, such as the command that brings a project back.
    var hint: String? = nil
}

/// A suggestion: a group of items that share a location, a risk level and a way of being removed.
nonisolated struct Finding: Identifiable, Sendable {
    let id: String
    var area: Area
    var tier: SafetyTier
    var title: String
    var summary: String
    var explanation: String
    var method: CleanMethod
    /// The path or command shown next to the method verb.
    var actionTarget: String
    var items: [FindingItem]
    var note: String? = nil
    /// An app that should quit before this finding is cleaned.
    var quitBundleID: String? = nil

    var size: Int64 { items.reduce(0) { $0 + $1.size } }
}

nonisolated struct AreaScanResult: Sendable {
    var findings: [Finding] = []
    /// Why the area produced nothing, when that is worth telling the user.
    var skipReason: String? = nil
    /// Folders macOS would not let the app read, named the way the user knows them.
    var unreadable: [String] = []
}

/// Everything a scanner needs to know about the Mac and the user's preferences.
nonisolated struct ScanContext: Sendable {
    var home: URL
    var now = Date()
    var staleDays = 60
    var recentBuildDays = 7
    var projectRoots: [URL] = []

    var staleCutoff: Date { now.addingTimeInterval(-Double(staleDays) * 86_400) }
    var recentBuildCutoff: Date { now.addingTimeInterval(-Double(recentBuildDays) * 86_400) }

    /// The path with the home folder written as `~`.
    func tilde(_ url: URL) -> String {
        let path = url.path
        let homePath = home.path
        guard path == homePath || path.hasPrefix(homePath + "/") else { return path }
        return "~" + path.dropFirst(homePath.count)
    }

    /// "4 months ago".
    func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }
}

nonisolated struct DiskInfo: Sendable, Equatable {
    var name: String
    var capacity: Int64
    var free: Int64

    var used: Int64 { max(0, capacity - free) }
    var isLow: Bool { capacity > 0 && (Double(free) / Double(capacity) < 0.10 || free < 20_000_000_000) }

    static func current(for location: URL = FileManager.default.homeDirectoryForCurrentUser) -> DiskInfo {
        var url = location
        url.removeAllCachedResourceValues()
        let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey,
        ])
        let name = (try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeNameKey]))?.volumeName
        let free = values?.volumeAvailableCapacityForImportantUsage ?? Int64(values?.volumeAvailableCapacity ?? 0)
        return DiskInfo(name: name ?? "Macintosh HD", capacity: Int64(values?.volumeTotalCapacity ?? 0), free: free)
    }
}
