//
//  SharedTempScanner.swift
//  SwiftMacCleaner
//

import Foundation

/// Scratch space programs left in /private/tmp, the temp folder every program on the Mac shares.
///
/// macOS empties the folder at each restart, so nothing in it is meant to last. What matters is not
/// to pull anything out from under a program that is running. An item is offered only when all of it
/// is this user's, it holds no socket or pipe, no running program has anything in it open or is
/// standing in it, and nothing in it has changed for a day.
///
/// A folder that fails those tests is not given up on. It is often a busy folder full of idle ones,
/// one for each session of some tool, so what it holds is looked at the same way, three levels down.
/// A folder programs talk through, with a socket or pipe directly in it, is left alone whole.
nonisolated enum SharedTempScanner {
    static let idleDays = 1.0
    /// Idle this long, an item at the top is as settled as what sits in the per-user temp folders, and is ticked like it.
    static let settledDays = CachesLogsScanner.tempIdleDays
    static let minimumSize: Int64 = 10_000_000
    /// Left alone and this big, an item is listed with the reason, so the folder's size adds up.
    static let listedSize: Int64 = 50_000_000
    static let depth = 3

    /// A file or folder in the temp folder, with what one pass over it found.
    struct Entry: Sendable {
        var path: String
        var isDirectory: Bool
        var size: Int64 = 0
        /// The latest change to it or to anything inside, in seconds since 1970.
        var newest = 0
        /// It is a socket, a pipe or a device, or one is somewhere inside it.
        var hasSpecial = false
        /// One sits directly in it, which makes it a folder programs talk through.
        var holdsSpecial = false
        /// Something in it belongs to another user, or could not be looked at.
        var isMixed = false
        /// What is directly inside and big enough to be offered by itself, down to `depth` levels.
        var children: [Entry] = []
    }

    /// What the folder gives: items settled enough to be ticked, items that need a look, and the big
    /// ones left alone with the reason.
    struct Offers: Sendable {
        var settled: [FindingItem] = []
        var idle: [FindingItem] = []
        var protected: [ProtectedItem] = []

        var isEmpty: Bool { settled.isEmpty && idle.isEmpty }

        mutating func add(_ other: Offers) {
            settled += other.settled
            idle += other.idle
            protected += other.protected
        }
    }

    /// How small is too small to offer, and how big is big enough to list when left alone.
    struct Sizes: Sendable {
        var minimum = SharedTempScanner.minimumSize
        var listed = SharedTempScanner.listedSize
    }

    static func scan(_ context: ScanContext, root: URL = GuardRoots.sharedTemporaryFolder, uid: uid_t = getuid(),
                     openFiles: OpenFiles, sizes: Sizes = Sizes()) -> Offers {
        var offers = Offers()
        for entry in entries(in: root, uid: uid, minimumSize: sizes.minimum) {
            offers.add(sort(entry, level: 1, context: context, openFiles: openFiles, sizes: sizes))
        }
        offers.settled.sort { $0.size > $1.size }
        offers.idle.sort { $0.size > $1.size }
        return offers
    }

    // MARK: Measuring

    private struct Frame {
        var entry: Entry
        /// Left out whole: hidden, Apple's, or another user's.
        var isSkipped = false
    }

    /// Everything directly inside `root` that is this user's to remove, measured in one pass, with the
    /// larger things inside each folder kept down to `depth` levels. It follows no links and reads no file.
    static func entries(in root: URL, uid: uid_t, depth: Int = depth, minimumSize: Int64 = minimumSize) -> [Entry] {
        guard let path = strdup(root.path) else { return [] }
        defer { free(path) }
        var arguments: [UnsafeMutablePointer<CChar>?] = [path, nil]
        guard let stream = fts_open(&arguments, FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV, nil) else { return [] }
        defer { fts_close(stream) }

        var frames: [Frame] = []
        var hardLinks = Set<UInt64>()
        var top: [Entry] = []
        var visited = 0
        /// Adds a finished file or folder to the folder it is in, and keeps it by name when it is worth offering by itself.
        func add(_ child: Entry, level: Int) {
            guard !frames.isEmpty else { return }
            let parent = frames.count - 1
            frames[parent].entry.size += child.size
            frames[parent].entry.newest = max(frames[parent].entry.newest, child.newest)
            frames[parent].entry.hasSpecial = frames[parent].entry.hasSpecial || child.hasSpecial
            frames[parent].entry.holdsSpecial = frames[parent].entry.holdsSpecial || (child.hasSpecial && !child.isDirectory)
            frames[parent].entry.isMixed = frames[parent].entry.isMixed || child.isMixed
            if level <= depth, child.size >= minimumSize { frames[parent].entry.children.append(child) }
        }

        while let entry = fts_read(stream) {
            visited += 1
            if visited % 4096 == 0, Task.isCancelled { return [] }
            let level = Int(entry.pointee.fts_level)
            let kind = Int32(entry.pointee.fts_info)
            switch kind {
            case FTS_D:
                var frame = Frame(entry: Entry(path: String(cString: entry.pointee.fts_path), isDirectory: true))
                if let status = entry.pointee.fts_statp?.pointee {
                    frame.entry.size = Int64(status.st_blocks) * 512
                    frame.entry.newest = Int(status.st_mtimespec.tv_sec)
                    frame.entry.isMixed = status.st_uid != uid
                    if level == 1, status.st_uid != uid || skipsName(of: entry) {
                        frame.isSkipped = true
                        fts_set(stream, entry, FTS_SKIP)
                    }
                }
                frames.append(frame)

            case FTS_DP, FTS_DNR:
                // FTS_DNR arrives in place of the usual visit on the way out when a folder cannot be opened.
                guard var frame = frames.popLast() else { continue }
                if kind == FTS_DNR { frame.entry.isMixed = true }
                if frames.isEmpty {
                    top = frame.entry.children
                } else if !frame.isSkipped {
                    add(frame.entry, level: level)
                }

            case FTS_F, FTS_SL, FTS_SLNONE, FTS_DEFAULT:
                guard let status = entry.pointee.fts_statp?.pointee else { continue }
                if level == 1, status.st_uid != uid || skipsName(of: entry) { continue }
                if kind == FTS_F, status.st_nlink > 1, !hardLinks.insert(UInt64(status.st_ino)).inserted { continue }
                let type = status.st_mode & S_IFMT
                var file = Entry(path: "", isDirectory: false)
                file.size = Int64(status.st_blocks) * 512
                file.newest = Int(status.st_mtimespec.tv_sec)
                file.hasSpecial = type == S_IFSOCK || type == S_IFIFO || type == S_IFCHR || type == S_IFBLK
                file.isMixed = status.st_uid != uid
                if level <= depth, file.size >= minimumSize { file.path = String(cString: entry.pointee.fts_path) }
                add(file, level: level)

            case FTS_NS, FTS_ERR:
                if !frames.isEmpty { frames[frames.count - 1].entry.isMixed = true }

            default:
                break
            }
        }
        return top
    }

    /// Whether something at the top of the folder is left out by its name: hidden, or Apple's own.
    private static func skipsName(of entry: UnsafeMutablePointer<FTSENT>) -> Bool {
        let name = entry.pointee.fts_path.advanced(by: Int(entry.pointee.fts_pathlen) - Int(entry.pointee.fts_namelen))
        return name.pointee == 0x2E || strncmp(name, "com.apple.", 10) == 0
    }

    // MARK: Deciding

    /// Why an entry is not offered as it stands. Nil when it may be.
    enum Hold: Sendable, Equatable {
        case talksThrough, mixed, inUse, recent
    }

    static func hold(on entry: Entry, context: ScanContext, openFiles: OpenFiles) -> Hold? {
        if entry.hasSpecial { return .talksThrough }
        if entry.isMixed { return .mixed }
        if openFiles.isInUse(URL(fileURLWithPath: entry.path)) { return .inUse }
        let cutoff = context.now.addingTimeInterval(-idleDays * 86_400)
        return Date(timeIntervalSince1970: Double(entry.newest)) > cutoff ? .recent : nil
    }

    /// Offers the entry, or what can go from inside it, or lists it as left alone.
    private static func sort(_ entry: Entry, level: Int, context: ScanContext, openFiles: OpenFiles, sizes: Sizes) -> Offers {
        var offers = Offers()
        // Nothing this small is offered, and nothing inside it can be bigger.
        guard entry.size >= sizes.minimum else { return offers }
        let url = URL(fileURLWithPath: entry.path, isDirectory: entry.isDirectory)
        let folder = url.deletingLastPathComponent().path
        let changed = Date(timeIntervalSince1970: Double(entry.newest))
        guard let hold = hold(on: entry, context: context, openFiles: openFiles) else {
            let item = FindingItem(
                id: "caches.tmp/\(entry.path)",
                title: url.lastPathComponent,
                detail: "In \(folder), untouched since \(context.relative(changed))",
                size: entry.size,
                paths: [url]
            )
            let isSettled = level == 1 && changed <= context.now.addingTimeInterval(-settledDays * 86_400)
            if isSettled { offers.settled.append(item) } else { offers.idle.append(item) }
            return offers
        }
        // A busy folder may be full of idle ones. One that programs talk through is not picked apart.
        if entry.isDirectory, level < depth, !entry.holdsSpecial {
            for child in entry.children {
                offers.add(sort(child, level: level + 1, context: context, openFiles: openFiles, sizes: sizes))
            }
            if !offers.isEmpty { return offers }
            // Nothing in it can go, so it is the folder itself that is left alone, not each thing in it.
            offers = Offers()
        }
        // Worth saying so for something big, unless it is simply not this user's.
        guard entry.size >= sizes.listed, hold != .mixed else { return offers }
        let why = switch hold {
        case .talksThrough: "Running programs talk through a socket or pipe in it"
        case .inUse: "A running program has files open in it"
        case .recent, .mixed: "Changed \(context.relative(changed)), so something still writes to it"
        }
        offers.protected.append(ProtectedItem(
            id: "caches.tmp.kept/\(entry.path)",
            area: .cachesLogs,
            title: url.lastPathComponent,
            why: "In \(folder). \(why)",
            rule: hold == .recent ? .recentlyUsed : .inUse,
            size: entry.size
        ))
        return offers
    }

    // MARK: Findings

    /// The finding for what needs a look before it goes: idle for a day, but not settled for a week,
    /// or sitting inside a folder that is still busy.
    static func finding(for items: [FindingItem], root: URL = GuardRoots.sharedTemporaryFolder) -> Finding? {
        guard !items.isEmpty else { return nil }
        return Finding(
            id: "caches.tmp",
            area: .cachesLogs,
            aftermath: .irreplaceable,
            title: "Idle work folders in \(root.path)",
            summary: "\(items.count) \(items.count == 1 ? "item" : "items") untouched for a day or more",
            explanation: "Scratch space programs left in the temp folder every program shares. macOS empties that folder at each restart, so nothing in it was meant to last. Only what has sat untouched for a day, holds no socket, and has nothing open in a running program is offered. It goes to the Trash rather than being deleted, in case you parked something there yourself.",
            method: .trash,
            actionTarget: root.path,
            items: items
        )
    }
}
