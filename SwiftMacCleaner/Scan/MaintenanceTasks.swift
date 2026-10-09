//
//  MaintenanceTasks.swift
//  SwiftMacCleaner
//

import Foundation

/// A chore macOS does not do by itself, or not often enough. The Performance scan weighs each one up
/// and says which are worth running now; the user runs them from the manager.
nonisolated enum MaintenanceTask: String, CaseIterable, Identifiable, Sendable {
    case flushDNS, freeMemory, purgeableSpace, speedUpMail, reindexSpotlight, repairPermissions, rebuildLaunchServices

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flushDNS: "Flush DNS Cache"
        case .freeMemory: "Free Up Memory"
        case .purgeableSpace: "Free Up Purgeable Space"
        case .speedUpMail: "Speed Up Mail"
        case .reindexSpotlight: "Reindex Spotlight"
        case .repairPermissions: "Repair Home Folder Permissions"
        case .rebuildLaunchServices: "Rebuild Open With Menus"
        }
    }

    /// What it does, in a sentence.
    var summary: String {
        switch self {
        case .flushDNS: "Forgets the addresses macOS has looked up, so sites that moved or a changed network stop failing to load."
        case .freeMemory: "Hands pages apps no longer use back to the pool, so the next app to open does not have to wait for them."
        case .purgeableSpace: "Asks macOS to give back the space it is holding in reserve: old snapshots and files it can fetch again."
        case .speedUpMail: "Compacts Mail's mailbox index, which grows with every message and slows searching when it is large."
        case .reindexSpotlight: "Throws away the Spotlight index and builds it again, for when search misses files you know are there."
        case .repairPermissions: "Resets the permissions of your home folder to what macOS expects, for when apps cannot save into your own folders."
        case .rebuildLaunchServices: "Rebuilds the list of which app opens which file, which clears duplicate entries from Open With menus."
        }
    }

    /// The longer story, behind the info button.
    var explanation: String {
        switch self {
        case .flushDNS:
            "macOS keeps the answers to recent name lookups so pages open faster. After a server moves, a VPN connects or the network changes, a stale answer can send Safari to the wrong place. Flushing the cache costs nothing: the next lookup simply asks again. Runs dscacheutil -flushcache and restarts mDNSResponder, which needs your password."
        case .freeMemory:
            "macOS keeps pages that apps have finished with in case they are wanted again, and gives them up when something else needs the room. Purging hands them back now instead, which helps when a memory-hungry app is about to start. Runs purge, which needs your password. Apps keep everything they are using."
        case .purgeableSpace:
            "The purgeable figure in About This Mac is space macOS could give back if asked: local Time Machine snapshots, caches it can rebuild, and files it can download again. It only does so when the disk is nearly full. This task reserves the disk's free space for a moment, which makes macOS evict what it can, then lets the space go. Nothing you made is touched, and nothing is deleted that macOS would not delete itself."
        case .speedUpMail:
            "Mail keeps an index of every message in a database called Envelope Index. It grows with every message and never shrinks on its own, and a large one makes searching and opening mailboxes slow. This task runs VACUUM on it, which rewrites the database compactly. Mail has to be quit while it runs, and reading the Mail folder needs Full Disk Access."
        case .reindexSpotlight:
            "Spotlight keeps an index of everything on the disk. When it falls out of step, searches miss files that are there, or Finder shows wrong sizes. Erasing the index makes Spotlight build a fresh one, which takes from half an hour to a few hours in the background and uses the CPU meanwhile. Runs mdutil -E /, which needs your password."
        case .repairPermissions:
            "Each file in your home folder says who may read and change it. Restores, migrations and some installers leave those settings wrong, and then apps cannot save their documents or preferences. This resets them to what macOS expects for your account. Runs diskutil resetUserPermissions, which needs your password and takes a minute."
        case .rebuildLaunchServices:
            "Launch Services keeps the list of which app opens which kind of file. Apps that were copied, moved or kept in several versions leave duplicate entries, so Open With menus list the same app twice and files open in the wrong one. This rebuilds the list from the apps that are installed now. Runs lsregister, which needs no password."
        }
    }

    /// The symbol on its lens. These are not features of the app, so they are system symbols.
    var symbol: String {
        switch self {
        case .flushDNS: "network"
        case .freeMemory: "memorychip"
        case .purgeableSpace: "internaldrive"
        case .speedUpMail: "envelope"
        case .reindexSpotlight: "magnifyingglass"
        case .repairPermissions: "lock.open"
        case .rebuildLaunchServices: "square.on.square"
        }
    }

    /// Whether it runs as root, so macOS asks for the password.
    var needsPassword: Bool {
        switch self {
        case .flushDNS, .freeMemory, .reindexSpotlight, .repairPermissions: true
        case .purgeableSpace, .speedUpMail, .rebuildLaunchServices: false
        }
    }

    /// Something that must not be running while the task does its work.
    var waitsFor: InUseCheck? {
        self == .speedUpMail ? .app(bundleID: "com.apple.mail", name: "Mail") : nil
    }

    /// What is run, named the way the receipt names it.
    var actionTarget: String {
        switch self {
        case .flushDNS: "dscacheutil -flushcache and killall -HUP mDNSResponder"
        case .freeMemory: "purge"
        case .purgeableSpace: "a reservation of the disk's free space"
        case .speedUpMail: "sqlite3 VACUUM on Mail's Envelope Index"
        case .reindexSpotlight: "mdutil -E /"
        case .repairPermissions: "diskutil resetUserPermissions"
        case .rebuildLaunchServices: "lsregister -kill -r"
        }
    }

    static let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

    /// The line that does the work for a task that runs as root. These are joined into one script,
    /// so the password is asked for once however many of them are ticked.
    func adminShellLine(uid: uid_t) -> String? {
        switch self {
        case .flushDNS: "/usr/bin/dscacheutil -flushcache && /usr/bin/killall -HUP mDNSResponder"
        case .freeMemory: "/usr/sbin/purge"
        case .reindexSpotlight: "/usr/bin/mdutil -i on / >/dev/null 2>&1; /usr/bin/mdutil -E / >/dev/null"
        case .repairPermissions: "/usr/sbin/diskutil resetUserPermissions / \(uid) >/dev/null"
        case .purgeableSpace, .speedUpMail, .rebuildLaunchServices: nil
        }
    }

    /// The command for a task that runs as the user. `mailIndex` is the Envelope Index the scan found;
    /// `executable` is this app's own program, which reserves the disk when run with `--free-purgeable`.
    func userCommand(mailIndex: URL?, executable: String) -> [String]? {
        switch self {
        case .purgeableSpace: [executable, "--free-purgeable"]
        case .speedUpMail: mailIndex.map { ["/usr/bin/sqlite3", $0.path, "VACUUM; REINDEX;"] }
        case .rebuildLaunchServices: [Self.lsregister, "-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"]
        case .flushDNS, .freeMemory, .reindexSpotlight, .repairPermissions: nil
        }
    }
}

/// What the scan made of one task: whether it is worth running now, and why.
nonisolated struct MaintenanceCheck: Identifiable, Sendable, Hashable {
    var task: MaintenanceTask
    /// Why it is worth running now. Nil for a task that is only listed, for whenever the user wants it.
    var reason: String? = nil
    /// What the task is worth, when that can be measured: the purgeable space, or the size of Mail's index.
    var size: Int64 = 0
    /// Why it cannot run on this Mac. Nil when it can.
    var unavailable: String? = nil
    var lastRun: Date? = nil

    var id: String { task.rawValue }
    var isAvailable: Bool { unavailable == nil }
    var isRecommended: Bool { reason != nil && isAvailable }
}

/// Weighs up the maintenance tasks. The facts are gathered once from the Mac; deciding on them is
/// a pure function, so the rules can be tested without one.
nonisolated enum MaintenanceScanner {
    /// What Mail's index is like on this Mac.
    enum MailIndex: Sendable, Hashable {
        /// Mail has no index here: it was never set up, or keeps nothing locally.
        case none
        /// macOS would not let the app read the Mail folder.
        case unreadable
        case found(URL, Int64)

        var url: URL? {
            if case .found(let url, _) = self { url } else { nil }
        }
    }

    /// What the checks are decided on. Tests make one up.
    struct Facts: Sendable, Hashable {
        var purgeable: Int64 = 0
        /// From macOS's own figure. Nil when it could not be asked.
        var freeMemoryPercent: Int? = nil
        /// Whether Spotlight is indexing the disk. Nil when it could not be asked.
        var spotlightIndexing: Bool? = nil
        var mailIndex = MailIndex.none
        var hasLaunchServicesTool = true
    }

    static let weekly: TimeInterval = 7 * 86_400
    static let monthly: TimeInterval = 30 * 86_400
    /// Below this, giving back purgeable space is not worth a minute of the disk's time.
    static let purgeableWorthIt: Int64 = 1_000_000_000
    static let mailIndexWorthIt: Int64 = 200_000_000
    static let lowMemoryPercent = 25

    /// The checks, in the order the tasks are listed.
    static func checks(facts: Facts, lastRuns: [MaintenanceTask: Date], now: Date = Date()) -> [MaintenanceCheck] {
        MaintenanceTask.allCases.map { task in
            var check = MaintenanceCheck(task: task, lastRun: lastRuns[task])
            let since = lastRuns[task].map { now.timeIntervalSince($0) }
            switch task {
            case .flushDNS:
                if since == nil {
                    check.reason = "Never run on this Mac. Worth doing once a week, and after any network trouble."
                } else if let since, since >= weekly {
                    check.reason = "Last run \(relative(since)). Worth doing once a week."
                }
            case .freeMemory:
                if let free = facts.freeMemoryPercent, free < lowMemoryPercent {
                    check.reason = "Only \(free)% of memory is free. Pages apps have finished with can go back to the pool now."
                }
            case .purgeableSpace:
                check.size = facts.purgeable
                if facts.purgeable >= purgeableWorthIt {
                    check.reason = "macOS is holding \(ByteFormat.string(facts.purgeable)) in reserve that it could give back."
                }
            case .speedUpMail:
                switch facts.mailIndex {
                case .none:
                    check.unavailable = "Mail keeps no mailbox index on this Mac."
                case .unreadable:
                    check.unavailable = "macOS keeps the Mail folder private. Grant Full Disk Access to include it."
                case .found(_, let size):
                    check.size = size
                    if size >= mailIndexWorthIt, since.map({ $0 >= monthly }) ?? true {
                        check.reason = "Mail's index is \(ByteFormat.string(size)). Compacting it makes searching and opening mailboxes quicker."
                    }
                }
            case .reindexSpotlight:
                if facts.spotlightIndexing == false {
                    check.reason = "Spotlight is not indexing this disk, so search finds nothing new."
                }
            case .repairPermissions:
                break
            case .rebuildLaunchServices:
                if !facts.hasLaunchServicesTool {
                    check.unavailable = "This version of macOS has no lsregister tool."
                }
            }
            return check
        }
    }

    private static func relative(_ interval: TimeInterval) -> String {
        let days = Int(interval / 86_400)
        if days < 1 { return "today" }
        if days == 1 { return "yesterday" }
        if days < 14 { return "\(days) days ago" }
        if days < 60 { return "\(days / 7) weeks ago" }
        return "\(days / 30) months ago"
    }

    // MARK: Gathering

    /// Reads the facts off this Mac. Each probe is short; none changes anything.
    @concurrent
    static func gather(home: URL) async -> Facts {
        Facts(
            purgeable: DiskInfo.current(for: home).purgeable,
            freeMemoryPercent: freeMemoryPercent(),
            spotlightIndexing: spotlightIndexing(),
            mailIndex: mailIndex(home: home),
            hasLaunchServicesTool: FileManager.default.isExecutableFile(atPath: MaintenanceTask.lsregister)
        )
    }

    /// Mail's Envelope Index, wherever the current mailbox format keeps it (`~/Library/Mail/V10/MailData`).
    static func mailIndex(home: URL) -> MailIndex {
        let mail = home.appending(path: "Library/Mail")
        let names: [String]
        do {
            names = try FileManager.default.contentsOfDirectory(atPath: mail.path)
        } catch {
            return Files.isPermissionError(error) ? .unreadable : .none
        }
        let indexes = names
            .filter { $0.hasPrefix("V") }
            .map { mail.appending(path: $0).appending(path: "MailData/Envelope Index") }
            .filter(Files.exists)
        guard let newest = indexes.max(by: { (Files.modificationDate($0) ?? .distantPast) < (Files.modificationDate($1) ?? .distantPast) }) else {
            return .none
        }
        // The index is a SQLite database with a write-ahead log beside it; VACUUM folds the log in.
        let size = [newest, newest.appendingPathExtension("wal"), URL(fileURLWithPath: newest.path + "-wal")]
            .reduce(Int64(0)) { $0 + (fileSize($1) ?? 0) }
        return .found(newest, size)
    }

    private static func fileSize(_ url: URL) -> Int64? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int64
    }

    /// macOS's own figure, from `memory_pressure`.
    static func freeMemoryPercent() -> Int? {
        guard let output = Shell.run("/usr/bin/memory_pressure", [], timeout: 10), output.succeeded else { return nil }
        return parseFreeMemory(output.stdout)
    }

    static func parseFreeMemory(_ output: String) -> Int? {
        for line in output.split(separator: "\n") where line.contains("memory free percentage") {
            let digits = line.split(separator: ":").last?.trimmingCharacters(in: .whitespaces).dropLast() ?? ""
            return Int(digits)
        }
        return nil
    }

    /// Whether Spotlight indexes the data volume, which is where the user's files live on a modern Mac.
    static func spotlightIndexing() -> Bool? {
        let data = "/System/Volumes/Data"
        let volume = Files.isDirectory(URL(fileURLWithPath: data)) ? data : "/"
        guard let output = Shell.run("/usr/bin/mdutil", ["-s", volume], timeout: 10), output.succeeded else { return nil }
        return parseSpotlight(output.stdout)
    }

    static func parseSpotlight(_ output: String) -> Bool? {
        if output.contains("Indexing enabled") { return true }
        if output.contains("Indexing disabled") || output.contains("Indexing and searching disabled") { return false }
        return nil
    }
}
