//
//  Models.swift
//  SwiftMacCleaner
//

import Foundation

/// A part of the disk the app knows how to look at.
nonisolated enum Area: String, CaseIterable, Identifiable, Sendable {
    case xcode, projects, android, containers, packageCaches, toolchains, ides, models
    case cachesLogs, trash, snapshots
    case largeFiles
    case leftovers, installers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .xcode: "Xcode"
        case .projects: "Projects"
        case .android: "Android and Gradle"
        case .containers: "Containers and VMs"
        case .packageCaches: "Package caches"
        case .toolchains: "Toolchains"
        case .ides: "IDEs and editors"
        case .models: "AI models and datasets"
        case .cachesLogs: "Caches and logs"
        case .trash: "Trash"
        case .snapshots: "Snapshots and backups"
        case .largeFiles: "Large old downloads"
        case .leftovers: "App leftovers"
        case .installers: "Installers"
        }
    }

    var summary: String {
        switch self {
        case .xcode: "DerivedData, device support, simulators, previews, archives, old Xcode versions"
        case .projects: "node_modules, Pods, build and target folders in stale projects"
        case .android: "~/.gradle, emulators, SDK system images"
        case .containers: "Docker, OrbStack, Colima, minikube: unused images, build cache, idle machines"
        case .packageCaches: "npm, pnpm, Yarn, Go, Cargo, pip, Composer, gems, Homebrew and more"
        case .toolchains: "Old JDKs, Node, Python, Ruby, Rust and Flutter versions"
        case .ides: "VS Code, Cursor, JetBrains and Android Studio caches, logs and old versions"
        case .models: "Hugging Face, Ollama, PyTorch and LM Studio downloads"
        case .cachesLogs: "~/Library/Caches, app containers, your temp folder, logs and crash reports"
        case .trash: "Items in the Trash that are waiting to be emptied"
        case .snapshots: "Time Machine local snapshots, iPhone backups"
        case .largeFiles: "Big files in Downloads that have sat untouched for months"
        case .leftovers: "Support files of apps that are no longer installed"
        case .installers: "Disk images and installer packages in Downloads"
        }
    }

    var symbol: String {
        switch self {
        case .xcode: "hammer"
        case .projects: "folder"
        case .android: "iphone"
        case .containers: "shippingbox"
        case .packageCaches: "archivebox"
        case .toolchains: "terminal"
        case .ides: "chevron.left.forwardslash.chevron.right"
        case .models: "brain"
        case .cachesLogs: "doc.text"
        case .trash: "trash"
        case .snapshots: "clock.arrow.circlepath"
        case .largeFiles: "arrow.down.doc"
        case .leftovers: "puzzlepiece.extension"
        case .installers: "externaldrive"
        }
    }

    /// The sidebar entry the area is filed under together with others. An area of the clean-up without
    /// one stands in the sidebar by itself.
    var group: AreaGroup? {
        switch self {
        case .xcode, .projects, .android, .containers, .packageCaches, .toolchains, .ides, .models: .developer
        case .cachesLogs, .trash, .snapshots: .system
        case .largeFiles, .leftovers, .installers: nil
        }
    }

    var isDeveloper: Bool { group == .developer }

    /// Whether the clean-up scan looks at the area. The others belong to Applications, which finds
    /// them with a scan of its own and lists them beside the apps they came from.
    var isCleanUp: Bool {
        switch self {
        case .leftovers, .installers: false
        default: true
        }
    }

    /// The areas of the clean-up, in the order they are listed.
    static let cleanUp = allCases.filter(\.isCleanUp)

    /// Areas added in version 2, called out on the home screen.
    var isNew: Bool {
        switch self {
        case .ides, .models, .snapshots: true
        default: false
        }
    }

    /// The areas stored under a key in the defaults. "Installers and Trash" was one area before it was
    /// split, so a Mac that had it switched off keeps both halves that are still part of the clean-up off.
    static func stored(forKey key: String, in defaults: UserDefaults = .standard) -> Set<Area> {
        Set((defaults.stringArray(forKey: key) ?? []).flatMap { name -> [Area] in
            name == "installersTrash" ? [.trash, .largeFiles] : [Area(rawValue: name)].compactMap { $0 }
        })
    }
}

/// Areas of the clean-up that share one sidebar entry, with a page of tiles that leads to each of them.
nonisolated enum AreaGroup: String, CaseIterable, Identifiable, Sendable {
    case system, developer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System Clean Up"
        case .developer: "Developer Clean Up"
        }
    }

    var symbol: String {
        switch self {
        case .system: "internaldrive"
        case .developer: "wrench.and.screwdriver"
        }
    }

    /// What the areas are called in a sentence: "the developer areas".
    var noun: String {
        switch self {
        case .system: "system"
        case .developer: "developer"
        }
    }

    var areas: [Area] { Area.allCases.filter { $0.group == self } }
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
        case .review: "Removable, but you would have to fetch or set these up again. Goes to the Trash, so it can be put back."
        case .careful: "Never selected for you. Remove only if you are sure."
        }
    }
}

/// How a finding is removed.
nonisolated enum CleanMethod: Sendable, Hashable {
    /// Removed for good, right away.
    case delete
    /// Moved to the Trash, so space comes back once the Trash is emptied, and it can be put back.
    case trash
    /// Handed to the tool that owns the data, such as `docker` or `xcrun simctl`.
    case command
    /// A command that only root may run. macOS asks for the password; nothing else does.
    case adminCommand

    var verb: String {
        switch self {
        case .delete: "Deletes"
        case .trash: "Moves to Trash"
        case .command: "Runs"
        case .adminCommand: "Runs with your password"
        }
    }

    var needsPassword: Bool { self == .adminCommand }
}

/// Something that has to be closed or stopped before a finding can be cleaned.
/// Nothing is ever quit or stopped on the user's behalf: the step simply waits for next time.
nonisolated enum InUseCheck: Sendable, Hashable {
    /// An app, by bundle identifier, with the name the user knows it by.
    case app(bundleID: String, name: String)
    /// A background process, matched by `pgrep -f` pattern, with what the user can do about it.
    case process(pattern: String, name: String, remedy: String)

    static let xcode = InUseCheck.app(bundleID: "com.apple.dt.Xcode", name: "Xcode")
    static let gradleDaemon = InUseCheck.process(pattern: "GradleDaemon", name: "A Gradle daemon",
                                                remedy: "Run gradle --stop")

    var name: String {
        switch self {
        case .app(_, let name): name
        case .process(_, let name, _): name
        }
    }

    /// The sentence shown on the receipt when the step was left alone.
    var skipReason: String {
        switch self {
        case .app(_, let name):
            "\(name) was open, so this was left alone. Quit \(name) and clean again to include it."
        case .process(_, let name, let remedy):
            "\(name) was running, so this was left alone. \(remedy) and clean again to include it."
        }
    }

    /// The short badge on a row.
    var badge: String {
        switch self {
        case .app(_, let name): "Waits for \(name)"
        case .process(_, let name, _): "\(name) running"
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
    /// macOS gives no size for this, so `size` is 0 and the row says so instead of showing a number.
    var sizeUnknown: Bool = false
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
    /// Something that must not be running while this finding is cleaned.
    var waitsFor: InUseCheck? = nil

    var size: Int64 { items.reduce(0) { $0 + $1.size } }
    var hasUnknownSize: Bool { items.contains(where: \.sizeUnknown) }
}

/// Why something that could have been offered was left alone.
nonisolated enum ProtectionRule: String, Sendable, CaseIterable {
    case recentlyUsed = "Recently used"
    case inUse = "In use"
    case protectedList = "Protected list"
    case neverSuggest = "Never Suggest"
    case defaultVersion = "Default version"
    case otherDisk = "Other disk"
    case shownOnly = "Shown only"
}

/// Something the scan found and deliberately did not offer, so the numbers add up.
nonisolated struct ProtectedItem: Identifiable, Sendable, Hashable {
    var id: String
    var area: Area
    var title: String
    var why: String
    var rule: ProtectionRule
    /// Nil when measuring it would have cost more than it is worth.
    var size: Int64?
}

nonisolated struct AreaScanResult: Sendable {
    var findings: [Finding] = []
    var protected: [ProtectedItem] = []
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
    /// How old a large file in Downloads must be before it is offered.
    var largeFileDays = 90
    var projectRoots: [URL] = []
    /// Paths the user never wants to see again, as the Never Suggest list stores them.
    var excluded: [String] = []
    /// The login shell's PATH and variables, read once for the whole scan. Without it, as in tests,
    /// no tool is asked where it keeps things and only the usual folders are looked at.
    var shell: Task<ShellEnvironment, Never>? = nil

    var staleCutoff: Date { now.addingTimeInterval(-Double(staleDays) * 86_400) }
    var recentBuildCutoff: Date { now.addingTimeInterval(-Double(recentBuildDays) * 86_400) }
    var largeFileCutoff: Date { now.addingTimeInterval(-Double(largeFileDays) * 86_400) }

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

    /// Whether the user asked never to see this path again.
    func isExcluded(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return excluded.contains { path == $0 || path.hasPrefix($0 + "/") }
    }
}

nonisolated struct DiskInfo: Sendable, Equatable {
    var name: String
    var capacity: Int64
    var free: Int64
    /// Space macOS can evict on its own, such as iCloud copies and local snapshots.
    var purgeable: Int64 = 0

    var used: Int64 { max(0, capacity - free - purgeable) }
    var isLow: Bool { capacity > 0 && (Double(free) / Double(capacity) < 0.10 || free < 20_000_000_000) }

    static func current(for location: URL = FileManager.default.homeDirectoryForCurrentUser) -> DiskInfo {
        var url = location
        url.removeAllCachedResourceValues()
        let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey,
        ])
        let name = (try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeNameKey]))?.volumeName
        let available = Int64(values?.volumeAvailableCapacity ?? 0)
        let important = values?.volumeAvailableCapacityForImportantUsage ?? available
        return DiskInfo(
            name: name ?? "Macintosh HD",
            capacity: Int64(values?.volumeTotalCapacity ?? 0),
            free: available,
            purgeable: max(0, important - available)
        )
    }
}
