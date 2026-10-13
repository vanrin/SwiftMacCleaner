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
        case .largeFiles: "Large old files"
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
        case .cachesLogs: "~/Library/Caches, app containers, temp folders, logs and crash reports"
        case .trash: "Items in the Trash that are waiting to be emptied"
        case .snapshots: "Time Machine local snapshots, iPhone backups"
        case .largeFiles: "Big files in Downloads, Documents and Desktop that have sat untouched for months"
        case .leftovers: "Support files of apps that are no longer installed"
        case .installers: "Disk images and installer packages in Downloads"
        }
    }

    /// The part of the app the area belongs to. Leftovers and installers belong to Applications, which
    /// is not a clean-up, so they have none.
    var group: AreaGroup? {
        switch self {
        case .xcode, .projects, .android, .containers, .packageCaches, .toolchains, .ides, .models: .developer
        case .cachesLogs, .trash, .snapshots: .system
        case .largeFiles: .largeFiles
        case .leftovers, .installers: nil
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

/// A clean-up: areas that share one sidebar entry, a scan of their own, a summary with a tile for each
/// area, and a manager. The overview runs every one of them together.
nonisolated enum AreaGroup: String, CaseIterable, Identifiable, Sendable {
    case system, developer, largeFiles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System Clean Up"
        case .developer: "Developer Clean Up"
        case .largeFiles: "Large old files"
        }
    }

    /// What the clean-up looks at, for a sentence: "Scanning the system areas", "2.1 GB found in Downloads, Documents and Desktop".
    var scope: String {
        switch self {
        case .system: "the system areas"
        case .developer: "the developer areas"
        case .largeFiles: "Downloads, Documents and Desktop"
        }
    }

    /// The sentence under the title of the opening screen.
    var intro: String {
        switch self {
        case .system: "Clear out what macOS and your apps leave behind as you use your Mac, and get the space back."
        case .developer: "Build output, caches, old toolchains, images and models that developer tools pile up. Source files are never touched."
        case .largeFiles: "Big files sitting in Downloads, Documents and Desktop that you have not opened, changed or moved for months. They go to the Trash, so they can be put back."
        }
    }

    /// The line under the opening screen's list, about what a scan does and does not do.
    var promise: String {
        switch self {
        case .system: "A scan shows everything that can go and ticks the part worth cleaning now. Nothing is removed until you confirm."
        case .developer: "A scan shows everything that can go and ticks what your tools rebuild by themselves. Source files are never touched, and nothing is removed until you confirm."
        case .largeFiles: "A scan only lists them. Nothing here is ever ticked for you, and what you tick goes to the Trash first, where it can be put back."
        }
    }

    /// Whether what the clean-up finds is junk, or the user's own files that happen to be large.
    var holdsJunk: Bool { self != .largeFiles }

    /// What happens to what is ticked, for the sentence under a summary's headline.
    var removalSentence: String {
        switch self {
        case .system: "Caches and logs are deleted and the Trash is emptied. Anything else you tick goes to the Trash first and can be put back."
        case .developer: "What rebuilds itself is deleted right away. Anything else you tick goes to the Trash first and can be put back."
        case .largeFiles: "What you tick goes to the Trash first and can be put back."
        }
    }

    var areas: [Area] { Area.allCases.filter { $0.group == self } }
}

/// What you are left with once something is removed. It is a fact about the thing, written on its
/// group and on the confirmation. Whether it is ticked for you is a separate matter: see `SmartKind`.
nonisolated enum Aftermath: Int, CaseIterable, Comparable, Sendable {
    case rebuilds, downloadsAgain, discarded, irreplaceable

    static func < (lhs: Aftermath, rhs: Aftermath) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .rebuilds: "Rebuilds itself"
        case .downloadsAgain: "Downloads again"
        case .discarded: "Cannot be put back"
        case .irreplaceable: "Cannot be recreated"
        }
    }

    var explanation: String {
        switch self {
        case .rebuilds: "Caches, logs and build output. Whatever made them makes them again the next time it runs."
        case .downloadsAgain: "You would have to fetch or set these up again. They go to the Trash first, so they can be put back."
        case .discarded: "Already thrown away. Emptying the Trash removes it for good."
        case .irreplaceable: "Once it is gone there is nothing to make it from again. Remove it only if you are sure."
        }
    }
}

/// A kind of thing Smart selection can tick after a scan, each with a switch of its own in Settings.
/// A finding that belongs to none of them is never ticked for the user.
nonisolated enum SmartKind: String, CaseIterable, Identifiable, Sendable {
    case appJunk, systemLogs, trash, buildOutput, staleProjects, unused

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appJunk: "App caches, logs and temporary files"
        case .systemLogs: "System logs"
        case .trash: "Everything in the Trash"
        case .buildOutput: "Build output and package caches"
        case .staleProjects: "Dependencies in stale projects"
        case .unused: "Simulators, toolchains and IDE versions you have stopped using"
        }
    }

    /// The line under the title, for the kinds that cost something.
    var note: String? {
        switch self {
        case .systemLogs: "Asks for your password once per clean"
        case .trash: "Emptying the Trash cannot be undone"
        case .unused: "They go to the Trash and have to be downloaded again"
        case .appJunk, .buildOutput, .staleProjects: nil
        }
    }

    /// Everything that rebuilds itself is on from the start, and so is the Trash. What has to be
    /// downloaded again waits to be asked for.
    var isOnByDefault: Bool { self != .unused }

    static let standard = Set(allCases.filter(\.isOnByDefault))

    /// The kinds stored under a key in the defaults, or the standard ones when nothing was stored.
    static func stored(forKey key: String, in defaults: UserDefaults) -> Set<SmartKind> {
        guard let names = defaults.stringArray(forKey: key) else { return standard }
        return Set(names.compactMap(SmartKind.init))
    }
}

/// The three ways to set every tick at once.
nonisolated enum SelectionPreset: String, CaseIterable, Identifiable, Sendable {
    case smart, everything, nothing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smart: "Smart"
        case .everything: "Everything"
        case .nothing: "Nothing"
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
    /// Old logs that belong to root, deleted by one script that runs as root. See `SystemLogs`.
    case adminDelete

    var verb: String {
        switch self {
        case .delete: "Deletes"
        case .trash: "Moves to Trash"
        case .command: "Runs"
        case .adminCommand: "Runs with your password"
        case .adminDelete: "Deletes with your password"
        }
    }

    var needsPassword: Bool { self == .adminCommand || self == .adminDelete }

    /// Whether what it removes is gone at once, with no copy left in the Trash.
    var isFinal: Bool { self != .trash }
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
    /// False keeps the item out of Smart selection even when its finding is part of it, as with the
    /// newest device support. Nil follows the finding.
    var preselected: Bool? = nil
    /// Shown in monospace under the detail, such as the command that brings a project back.
    var hint: String? = nil
    /// macOS gives no size for this, so `size` is 0 and the row says so instead of showing a number.
    var sizeUnknown: Bool = false
    /// What root is asked to delete, for an item of a finding that is removed with `.adminDelete`.
    var systemTarget: SystemLogs.Target? = nil
    /// The name the item is filed under by the app that keeps it, such as a cache folder's. While an
    /// app of that name is open the item waits, and the confirmation offers to ask the app to quit.
    var keptBy: String? = nil
}

/// A suggestion: a group of items that share a location, an aftermath and a way of being removed.
nonisolated struct Finding: Identifiable, Sendable {
    let id: String
    var area: Area
    var aftermath: Aftermath
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
    /// Apps write to these all the time, so a change since the scan says nothing about them and is
    /// not a reason to leave them. Whether the app that keeps each item is open is asked instead.
    var keepsChanging = false

    var size: Int64 { items.reduce(0) { $0 + $1.size } }
    var hasUnknownSize: Bool { items.contains(where: \.sizeUnknown) }
}

nonisolated extension Finding {
    /// Findings that have to be fetched again and are still part of Smart selection once their
    /// switch is on, because the scan only offers them after they have sat unused.
    static let unusedFindingIDs: Set<String> = ["xcode.simulators", "toolchains.unused", "ides.oldVersions"]

    /// The kind of thing this is to Smart selection, or nil when it is never ticked for the user.
    ///
    /// This is the whole rule, in one place: the Trash, what root deletes, what has gone unused, and
    /// otherwise only what rebuilds itself. Backups, archives, snapshots, models, disk images and the
    /// user's own files belong to no kind.
    var smart: SmartKind? {
        if area == .trash { return .trash }
        if method == .adminDelete { return .systemLogs }
        if Self.unusedFindingIDs.contains(id) { return .unused }
        guard aftermath == .rebuilds else { return nil }
        if area == .projects { return .staleProjects }
        if area.isDeveloper { return .buildOutput }
        return area == .cachesLogs ? .appJunk : nil
    }
}

nonisolated extension Sequence<Finding> {
    /// What Smart selection ticks: the items of every finding whose kind is switched on, less the
    /// ones their scanner keeps by default. It is what a scan ticks by itself, and so the only thing
    /// Scan and Clean, the menu bar and a clean after the weekly check may promise.
    func smartSelection(_ kinds: Set<SmartKind>) -> [FindingItem] {
        filter { $0.smart.map(kinds.contains) ?? false }.flatMap { finding in finding.items.filter { $0.preselected ?? true } }
    }
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
    case notYours = "Not yours"
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
    /// How long a large file must have sat untouched before it is offered.
    var largeFileDays = 90
    /// How big a file has to be to count as large, in bytes.
    var largeFileSize = LargeFileScanner.minimumSize
    var projectRoots: [URL] = []
    /// Paths the user never wants to see again, as the Never Suggest list stores them.
    var excluded: [String] = []
    /// The root-owned log folders to measure. Nil, as in tests, leaves them out of the scan.
    var systemLogRoots: [URL]? = nil
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
