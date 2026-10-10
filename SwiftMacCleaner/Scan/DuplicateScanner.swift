//
//  DuplicateScanner.swift
//  SwiftMacCleaner
//

import CryptoKit
import Foundation
import UniformTypeIdentifiers

/// What a duplicate is a file of, which is how the list is filtered.
nonisolated enum DuplicateKind: String, CaseIterable, Identifiable, Sendable {
    case images, videos, music, documents, archives, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .images: "Images"
        case .videos: "Videos"
        case .music: "Music"
        case .documents: "Documents"
        case .archives: "Archives"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .images: "photo"
        case .videos: "film"
        case .music: "music.note"
        case .documents: "doc.text"
        case .archives: "archivebox"
        case .other: "doc"
        }
    }

    /// Read from the ending of the file's name, the way Finder decides what a file is.
    init(fileExtension: String) {
        guard !fileExtension.isEmpty, let type = UTType(filenameExtension: fileExtension) else {
            self = .other
            return
        }
        self = if type.conforms(to: .image) {
            .images
        } else if type.conforms(to: .movie) || type.conforms(to: .video) {
            .videos
        } else if type.conforms(to: .audio) {
            .music
        } else if type.conforms(to: .archive) || type.conforms(to: .diskImage) {
            .archives
        } else if type.conforms(to: .content) {
            .documents
        } else {
            .other
        }
    }
}

/// One of several files that are the same to the last byte.
nonisolated struct DuplicateFile: Identifiable, Sendable, Hashable {
    var url: URL
    /// The file's length, which every copy in a group shares.
    var size: Int64
    /// What the file takes up on disk.
    var allocated: Int64
    var created: Date?
    var modified: Date?
    /// Whether the file shares its data with a clone, and what removing it alone would free.
    var storage: FileStorage
    /// Why the file cannot be ticked, for one that has to stay whatever the user wants.
    var lockedReason: String? = nil
    /// Which file this was when it was compared, so a file changed or swapped since is left alone.
    var inode: UInt64
    var modifiedNanoseconds: Int64

    var id: String { url.path }
    var isLocked: Bool { lockedReason != nil }
    /// A clone points at the same data as another file. Removing it alone gives next to nothing back.
    var sharesSpace: Bool { storage.cloneCount > 1 }

    /// Whether the file is still the one that was compared: the same file, as long, and not written since.
    var isUnchanged: Bool {
        var status = stat()
        guard lstat(url.path, &status) == 0, status.st_mode & S_IFMT == S_IFREG else { return false }
        return UInt64(status.st_ino) == inode && Int64(status.st_size) == size
            && DuplicateScanner.nanoseconds(status.st_mtimespec) == modifiedNanoseconds
    }
}

/// Files that are the same to the last byte, wherever they are and whatever they are called.
nonisolated struct DuplicateGroup: Identifiable, Sendable, Hashable {
    /// Stands for the content. No two groups share one.
    var id: String
    var kind: DuplicateKind
    /// The length of each copy.
    var size: Int64
    /// The copies, the one most worth keeping first.
    var files: [DuplicateFile]

    var name: String { files.first?.url.lastPathComponent ?? "" }

    /// What removing the given files would give back.
    ///
    /// Clones share their data, so the data goes only when the last file that points at it goes: every
    /// clone on the disk, not just the ones found here. Until then a clone gives back only what is its own.
    func freed(removing ids: Set<String>) -> Int64 {
        Dictionary(grouping: files, by: \.storage.cloneID).values.reduce(0) { total, family in
            let going = family.filter { ids.contains($0.id) }
            guard let count = family.first?.storage.cloneCount, !going.isEmpty else { return total }
            return total + (going.count >= count ? going.map(\.allocated).max() ?? 0 : going.reduce(0) { $0 + $1.storage.privateSize })
        }
    }

    /// What a tidy-up would remove: every copy that may go but the one most worth keeping. When a copy
    /// has to stay anyway, that one is the copy kept, and all the others may go.
    var extras: [DuplicateFile] {
        let removable = files.filter { !$0.isLocked }
        return files.contains(where: \.isLocked) ? removable : Array(removable.dropFirst())
    }

    /// The most the group can give back with one copy kept. Nothing, when the copies are clones of each other.
    var reclaimable: Int64 { freed(removing: Set(extras.map(\.id))) }

    /// How much each of the given files accounts for, adding up to `freed(removing:)`.
    func shares(removing going: [DuplicateFile]) -> [String: Int64] {
        var shares: [String: Int64] = [:]
        for family in Dictionary(grouping: going, by: \.storage.cloneID).values {
            let all = family.count >= (family.first?.storage.cloneCount ?? 1)
            for (index, file) in family.enumerated() {
                shares[file.id] = all ? (index == 0 ? family.map(\.allocated).max() ?? 0 : 0) : file.storage.privateSize
            }
        }
        return shares
    }
}

/// How far a look for duplicates has got.
nonisolated struct DuplicateProgress: Sendable, Equatable {
    enum Stage: Sendable {
        /// Walking the folders, noting every file's size.
        case looking
        /// Reading the files that share a size with another.
        case comparing
    }

    var stage = Stage.looking
    var filesSeen = 0
    /// Files that share their size with another, which is as many as have to be read.
    var toCompare = 0
    var compared = 0
    var bytesRead: Int64 = 0
    /// The folder being walked, or the file being read.
    var path = ""

    var fraction: Double { toCompare == 0 ? 0 : min(1, Double(compared) / Double(toCompare)) }
}

/// What a look for duplicates found.
nonisolated struct DuplicateScan: Sendable {
    /// The groups, the one that gives back the most first.
    var groups: [DuplicateGroup] = []
    var filesSeen = 0
    var bytesRead: Int64 = 0
    /// Files and folders left out because they are kept in the cloud and not on this Mac.
    var cloudOnly = 0
    /// Folders macOS would not let the app open, by path.
    var unreadable: [String] = []
    var duration: TimeInterval = 0

    var reclaimable: Int64 { groups.reduce(0) { $0 + $1.reclaimable } }
}

/// Finds files that are the same to the last byte. It only reads.
///
/// Files are first sorted by length, since two files of different lengths cannot be alike. Among files
/// of one length, clones are known to be alike without being read: the disk says they point at the same
/// data. The rest have their first and last 64 KB read, and only those that still agree are read whole.
///
/// What is left out is whatever is not the user's to tidy by hand: the Library, hidden files and
/// folders, apps and other packages, projects and repositories, the folders databases, caches and
/// package managers fill, the libraries Music and TV keep, and files with no type in their name, which
/// are parts of something rather than documents. In all of those the same file turns up more than once
/// on purpose, and taking one away breaks what it belongs to. A file of a type that is neither a
/// document, a picture, music, video nor an archive is compared only when it is large: small ones are
/// some program's data. A file kept only in the cloud is never downloaded to be compared.
nonisolated enum DuplicateScanner {
    /// Smaller files are not worth the reading: there are a great many of them and they give little back.
    static let minimumSize: Int64 = 100_000
    /// How large a file of an unknown type has to be: a model or a disk image is worth offering, a
    /// program's data files are not.
    static let minimumUnknownSize: Int64 = 50_000_000
    static let fingerprintChunk = 65_536
    static let readChunk = 1_048_576
    /// Folders a package manager, a build or a cache fills, where the same file turns up many times on purpose.
    static let skippedFolders: Set<String> = [
        "node_modules", "bower_components", "Pods", "Carthage", "DerivedData", "__pycache__", "site-packages", "venv",
        "bin", "Cache", "Caches", "cache", "caches",
    ]
    /// What marks a folder as one thing that keeps its own files in order: a repository, a project, a
    /// folder set up for containers, or the data folder of a database.
    static let treeMarkers: Set<String> = Set(StackDetector.projectKinds.flatMap(\.markers)).union([
        ".git", ".hg", ".svn",
        "docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml",
        "PG_VERSION", "WiredTiger", "ibdata1",
    ])
    static let treeSuffixes = StackDetector.projectKinds.flatMap(\.suffixes)
    /// Folders in the home folder that an app keeps in order itself. Relative to home.
    static let managedFolders = ["Library", "Applications", "Music/Music", "Music/iTunes", "Movies/TV"]
    /// The folders macOS gives every user. A stray project file in one of them does not make it a project.
    static let userFolders = ["Desktop", "Documents", "Downloads", "Movies", "Music", "Pictures", "Public"]

    /// A file that shares its length with at least one other, as the walk noted it.
    struct Candidate: Sendable, Hashable {
        var path: String
        var size: Int64
        var allocated: Int64
        var inode: UInt64
        /// More than one means the file has another name somewhere, so removing this name frees nothing.
        var links: Int
        var modifiedNanoseconds: Int64
        var createdNanoseconds: Int64
    }

    /// What walking the folders gave.
    struct Walk: Sendable {
        var bySize: [Int64: [Candidate]] = [:]
        var filesSeen = 0
        var cloudOnly = 0
        var unreadable: [String] = []
    }

    /// A candidate with what the disk says about its data.
    struct Member: Sendable {
        var candidate: Candidate
        var storage: FileStorage
    }

    /// Files of one length that the disk says are clones of each other, which makes them alike without
    /// a byte being read. A file that is nobody's clone is a family of one.
    struct Family: Sendable {
        var cloneID: UInt64
        var members: [Member]

        /// The one member that is read on behalf of all of them.
        var first: Candidate { members[0].candidate }
    }

    static func nanoseconds(_ time: timespec) -> Int64 { Int64(time.tv_sec) * 1_000_000_000 + Int64(time.tv_nsec) }

    private static func date(_ nanoseconds: Int64) -> Date? {
        nanoseconds > 0 ? Date(timeIntervalSince1970: Double(nanoseconds) / 1e9) : nil
    }

    // MARK: Scanning

    /// Looks through `roots` and gives back the groups of identical files. Nil when stopped early.
    ///
    /// `safety` is the guard a removal goes through later. A copy it would refuse is still listed, as
    /// one that stays, so no group offers a file that could not be acted on.
    @concurrent
    static func scan(roots: [URL], home: URL, safety: SafetyGuard, minimumSize: Int64 = minimumSize,
                     minimumUnknownSize: Int64 = minimumUnknownSize,
                     progress: @escaping @Sendable (DuplicateProgress) -> Void = { _ in }) async -> DuplicateScan? {
        let started = Date()
        let reporter = Reporter(progress)
        guard let walk = walk(roots: roots, home: home, minimumSize: minimumSize, minimumUnknownSize: minimumUnknownSize,
                              reporter: reporter) else { return nil }

        var groups: [DuplicateGroup] = []
        var kinds: [String: DuplicateKind] = [:]
        func add(_ families: [Family], id: String) {
            if let found = group(id: id, members: families.flatMap(\.members), home: home, safety: safety, kinds: &kinds) {
                groups.append(found)
            }
        }

        // Files of one length, sorted into the families the disk says are clones.
        var toRead: [Family] = []
        for candidates in walk.bySize.values where candidates.count > 1 {
            let members = candidates.map { candidate in
                Member(candidate: candidate,
                       storage: FileStorage.read(candidate.path) ?? .unshared(inode: candidate.inode, allocated: candidate.allocated))
            }
            let families = Dictionary(grouping: members, by: \.storage.cloneID).map { Family(cloneID: $0.key, members: $0.value) }
            if families.count == 1 {
                // Every file of this length is a clone of the others.
                add(families, id: "clones-\(families[0].cloneID)")
            } else {
                toRead += families
            }
        }
        guard !Task.isCancelled else { return nil }
        let total = toRead.count
        reporter.update { $0.stage = .comparing; $0.toCompare = total; $0.path = "" }

        // The first and last 64 KB of one file from each family.
        let prints = await concurrently(toRead, limit: 8) { family in
            (family, fingerprint(of: family.first, reporter: reporter))
        }
        guard !Task.isCancelled else { return nil }
        var alike: [String: [Family]] = [:]
        var readWhole: Set<String> = []
        for (family, print) in prints {
            guard let print else {
                reporter.update { $0.compared += 1 }
                continue
            }
            let key = "\(family.first.size)-\(print.digest)"
            alike[key, default: []].append(family)
            if print.isWhole { readWhole.insert(key) }
        }

        // Whatever still agrees is read from end to end, unless the fingerprint already was the whole file.
        var toDigest: [Family] = []
        for (key, families) in alike {
            if families.count > 1, !readWhole.contains(key) {
                toDigest += families
                continue
            }
            // Alike already, or alone: a family of several is a group by itself.
            if families.count > 1 {
                add(families, id: key)
            } else if families[0].members.count > 1 {
                add(families, id: "clones-\(families[0].cloneID)")
            }
            let count = families.count
            reporter.update { $0.compared += count }
        }
        let digests = await concurrently(toDigest, limit: 4) { family in
            (family, digest(of: family.first, reporter: reporter))
        }
        guard !Task.isCancelled else { return nil }
        var identical: [String: [Family]] = [:]
        for (family, digest) in digests {
            reporter.update { $0.compared += 1 }
            // One that could not be read to the end, or changed meanwhile, is left out with its clones.
            guard let digest else { continue }
            identical["\(family.first.size)-\(digest)", default: []].append(family)
        }
        for (key, families) in identical where families.reduce(0, { $0 + $1.members.count }) > 1 {
            add(families, id: key)
        }

        // The group that gives back the most first, then the largest copies, then by name.
        let ranked = groups.map { (group: $0, gain: $0.reclaimable) }.sorted { first, second in
            (first.gain, first.group.size) != (second.gain, second.group.size)
                ? (first.gain, first.group.size) > (second.gain, second.group.size)
                : first.group.name.localizedStandardCompare(second.group.name) == .orderedAscending
        }
        let final = reporter.finish()
        return DuplicateScan(groups: ranked.map(\.group), filesSeen: walk.filesSeen, bytesRead: final.bytesRead, cloudOnly: walk.cloudOnly,
                             unreadable: walk.unreadable, duration: Date().timeIntervalSince(started))
    }

    /// Runs `work` over the items, a few at a time. The results come back in no particular order.
    @concurrent
    private static func concurrently<Item: Sendable, Result: Sendable>(
        _ items: [Item], limit: Int, _ work: @escaping @Sendable (Item) -> Result
    ) async -> [Result] {
        await withTaskGroup(of: Result.self) { tasks in
            var results: [Result] = []
            results.reserveCapacity(items.count)
            var pending = items.makeIterator()
            for _ in 0..<limit {
                guard let item = pending.next() else { break }
                tasks.addTask { work(item) }
            }
            while let result = await tasks.next() {
                results.append(result)
                if let item = pending.next() { tasks.addTask { work(item) } }
            }
            return results
        }
    }

    // MARK: Walking

    /// The roots with any that sits inside another left out, so nothing is walked twice.
    static func distinct(_ roots: [URL]) -> [URL] {
        let paths = roots.map { $0.resolvingSymlinksInPath().standardizedFileURL.path }
        var kept: [String] = []
        for path in Set(paths).sorted(by: { $0.count < $1.count })
        where !kept.contains(where: { path == $0 || path.hasPrefix($0 == "/" ? "/" : $0 + "/") }) {
            kept.append(path)
        }
        return kept.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// Notes the length of every file worth comparing. Nil when stopped early. It follows no links,
    /// stays on each root's own disk, and never makes a folder kept in the cloud download itself.
    static func walk(roots: [URL], home: URL, minimumSize: Int64 = minimumSize, minimumUnknownSize: Int64 = minimumUnknownSize,
                     reporter: Reporter? = nil) -> Walk? {
        var walk = Walk()
        let homePath = home.resolvingSymlinksInPath().standardizedFileURL.path
        let managed = Set(managedFolders.map { homePath + "/" + $0 })
        let userFolders = Set(userFolders.map { homePath + "/" + $0 })
        var kinds: [String: DuplicateKind] = [:]
        var paths: [UnsafeMutablePointer<CChar>?] = distinct(roots).map { strdup($0.path) } + [nil]
        defer { paths.forEach { free($0) } }
        guard paths.count > 1, let stream = fts_open(&paths, FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV, nil) else { return walk }
        defer { fts_close(stream) }

        var named: Set<UInt64> = []
        var visited = 0
        while let entry = fts_read(stream) {
            visited += 1
            if visited % 2048 == 0 {
                if Task.isCancelled { return nil }
                let path = String(cString: entry.pointee.fts_path)
                let seen = walk.filesSeen
                reporter?.update { $0.filesSeen = seen; $0.path = path }
            }
            let kind = Int32(entry.pointee.fts_info)
            let isRoot = entry.pointee.fts_level == 0
            switch kind {
            case FTS_D:
                guard let status = entry.pointee.fts_statp?.pointee else { continue }
                if status.st_flags & UInt32(SF_DATALESS) != 0 {
                    walk.cloudOnly += 1
                    fts_set(stream, entry, FTS_SKIP)
                    continue
                }
                // The folder the user chose is walked whatever it is. What it holds goes by the rules.
                guard !isRoot else { continue }
                let path = String(cString: entry.pointee.fts_path)
                // Documents or Downloads with a stray package.json in it is still not a project.
                if skips(folderAt: path, managed: managed) || (!userFolders.contains(path) && isOwnTree(fts_children(stream, 0))) {
                    fts_set(stream, entry, FTS_SKIP)
                }

            case FTS_F:
                guard let status = entry.pointee.fts_statp?.pointee else { continue }
                // The name is the end of the path. A leading dot marks a hidden file.
                let name = entry.pointee.fts_path.advanced(by: Int(entry.pointee.fts_pathlen) - Int(entry.pointee.fts_namelen))
                guard name.pointee != 0x2E else { continue }
                walk.filesSeen += 1
                if status.st_flags & UInt32(SF_DATALESS) != 0 {
                    walk.cloudOnly += 1
                    continue
                }
                let size = Int64(status.st_size)
                guard size >= minimumSize else { continue }
                let fileName = String(cString: name)
                guard hasType(fileName) else { continue }
                if size < minimumUnknownSize {
                    let ending = (fileName as NSString).pathExtension.lowercased()
                    let kind = kinds[ending] ?? DuplicateKind(fileExtension: ending)
                    kinds[ending] = kind
                    if kind == .other { continue }
                }
                // A second name for a file already noted is the same file, not a copy of it.
                if status.st_nlink > 1, !named.insert(UInt64(status.st_ino)).inserted { continue }
                walk.bySize[size, default: []].append(Candidate(
                    path: String(cString: entry.pointee.fts_path), size: size, allocated: Int64(status.st_blocks) * 512,
                    inode: UInt64(status.st_ino), links: Int(status.st_nlink),
                    modifiedNanoseconds: nanoseconds(status.st_mtimespec), createdNanoseconds: nanoseconds(status.st_birthtimespec)
                ))

            case FTS_DNR, FTS_ERR:
                // Worth telling for a folder near the top, such as Documents when macOS keeps it private.
                if entry.pointee.fts_level <= 2 { walk.unreadable.append(String(cString: entry.pointee.fts_path)) }

            default:
                break
            }
        }
        return walk
    }

    /// Whether a folder inside the one being walked is left out with everything in it.
    static func skips(folderAt path: String, managed: Set<String>) -> Bool {
        let name = (path as NSString).lastPathComponent
        if name.hasPrefix(".") || skippedFolders.contains(name) || managed.contains(path) { return true }
        // An app, a photo library, a project file: one thing to the user, and not to be picked apart.
        return !(name as NSString).pathExtension.isEmpty
            && (try? URL(fileURLWithPath: path, isDirectory: true).resourceValues(forKeys: [.isPackageKey]))?.isPackage == true
    }

    /// Whether a folder with these entries keeps its own files in order, going by what sits directly
    /// inside it. `children` is the list the walk has just read, so looking costs nothing more.
    static func isOwnTree(_ children: UnsafeMutablePointer<FTSENT>?) -> Bool {
        guard let offset = MemoryLayout<FTSENT>.offset(of: \FTSENT.fts_name) else { return false }
        var child = children
        while let entry = child {
            let name = String(cString: UnsafeRawPointer(entry).advanced(by: offset).assumingMemoryBound(to: CChar.self))
            if treeMarkers.contains(name) || treeSuffixes.contains(where: name.hasSuffix) { return true }
            child = entry.pointee.fts_link
        }
        return false
    }

    /// Whether a file's name says what kind of file it is: an ending of letters and digits with a
    /// letter in it. "17368", "part.1" and "journal.0000000002" do not; they are pieces of something.
    static func hasType(_ name: String) -> Bool {
        let ending = (name as NSString).pathExtension
        return !ending.isEmpty && ending.count <= 12 && ending.contains(where: \.isLetter)
            && ending.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    // MARK: Reading

    /// The first and last 64 KB of a file as one digest, or the whole file when it is no longer than
    /// that. Nil when the file cannot be read or changed while it was.
    static func fingerprint(of candidate: Candidate, reporter: Reporter? = nil) -> (digest: String, isWhole: Bool)? {
        let descriptor = open(candidate.path, O_RDONLY | O_NOFOLLOW)
        guard descriptor >= 0 else { return nil }
        defer { close(descriptor) }
        let chunk = Int64(fingerprintChunk)
        let isWhole = candidate.size <= chunk * 2
        var hasher = SHA256()
        var buffer = [UInt8](repeating: 0, count: fingerprintChunk * 2)
        var ranges: [(offset: Int64, length: Int)] = [(offset: 0, length: isWhole ? Int(candidate.size) : fingerprintChunk)]
        if !isWhole { ranges.append((offset: candidate.size - chunk, length: fingerprintChunk)) }
        var bytes: Int64 = 0
        for range in ranges {
            let count = buffer.withUnsafeMutableBytes { pread(descriptor, $0.baseAddress, range.length, off_t(range.offset)) }
            guard count == range.length else { return nil }
            hasher.update(data: buffer[..<count])
            bytes += Int64(count)
        }
        reporter?.update { $0.bytesRead += bytes; $0.path = candidate.path }
        guard isSame(candidate, descriptor: descriptor) else { return nil }
        return (hex(hasher.finalize()), isWhole)
    }

    /// The digest of a whole file. Nil when it cannot be read, changed while it was, or the scan was stopped.
    static func digest(of candidate: Candidate, reporter: Reporter? = nil) -> String? {
        let descriptor = open(candidate.path, O_RDONLY | O_NOFOLLOW)
        guard descriptor >= 0 else { return nil }
        defer { close(descriptor) }
        // A file read once, to be compared, has no business in the cache other programs rely on.
        _ = fcntl(descriptor, F_NOCACHE, 1)
        var hasher = SHA256()
        var buffer = [UInt8](repeating: 0, count: readChunk)
        reporter?.update { $0.path = candidate.path }
        while true {
            if Task.isCancelled { return nil }
            let count = buffer.withUnsafeMutableBytes { read(descriptor, $0.baseAddress, $0.count) }
            guard count >= 0 else { return nil }
            if count == 0 { break }
            hasher.update(data: buffer[..<count])
            reporter?.update { $0.bytesRead += Int64(count) }
        }
        guard isSame(candidate, descriptor: descriptor) else { return nil }
        return hex(hasher.finalize())
    }

    /// Whether the open file is still the one the walk noted: as long, and not written since.
    private static func isSame(_ candidate: Candidate, descriptor: Int32) -> Bool {
        var status = stat()
        return fstat(descriptor, &status) == 0 && UInt64(status.st_ino) == candidate.inode
            && Int64(status.st_size) == candidate.size && nanoseconds(status.st_mtimespec) == candidate.modifiedNanoseconds
    }

    private static func hex(_ digest: SHA256.Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Groups

    /// Turns files known to be alike into a group. Nil when fewer than two are left, or none may go.
    static func group(id: String, members: [Member], home: URL, safety: SafetyGuard,
                      kinds: inout [String: DuplicateKind]) -> DuplicateGroup? {
        guard members.count > 1, let size = members.first?.candidate.size else { return nil }
        let counts = Dictionary(grouping: members, by: \.storage.cloneID).mapValues(\.count)
        var files = members.map { member in
            let candidate = member.candidate
            let storage = member.storage
            let url = URL(fileURLWithPath: candidate.path)
            var file = DuplicateFile(
                url: url, size: candidate.size, allocated: candidate.allocated,
                created: date(candidate.createdNanoseconds), modified: date(candidate.modifiedNanoseconds),
                storage: storage, inode: candidate.inode, modifiedNanoseconds: candidate.modifiedNanoseconds
            )
            if candidate.links > 1 {
                file.lockedReason = "It has a second name elsewhere on the disk, so removing this one would free nothing"
            } else if let refusal = safety.refusal(for: url) {
                file.lockedReason = lockedReason(for: refusal)
            }
            return file
        }
        guard files.contains(where: { !$0.isLocked }) else { return nil }
        let downloads = home.appending(path: "Downloads").path + "/"
        files.sort { first, second in
            keepingOrder(first, clonesHere: counts[first.storage.cloneID] ?? 1, downloads: downloads)
                < keepingOrder(second, clonesHere: counts[second.storage.cloneID] ?? 1, downloads: downloads)
        }
        let ending = files[0].url.pathExtension.lowercased()
        let kind = kinds[ending] ?? DuplicateKind(fileExtension: ending)
        kinds[ending] = kind
        return DuplicateGroup(id: id, kind: kind, size: size, files: files)
    }

    /// Where a copy stands when choosing the one to keep: lowest first. A copy that has to stay comes
    /// first, then one whose data would stay on the disk anyway, then the one that looks like the
    /// original: not named as a copy, not in Downloads, and the oldest.
    static func keepingOrder(_ file: DuplicateFile, clonesHere: Int, downloads: String) -> KeepingOrder {
        KeepingOrder(
            mayGo: file.isLocked ? 0 : 1,
            dataGoes: file.storage.cloneCount > clonesHere ? 0 : 1,
            looksLikeCopy: looksLikeCopy(file.url.deletingPathExtension().lastPathComponent) ? 1 : 0,
            inDownloads: file.url.path.hasPrefix(downloads) ? 1 : 0,
            created: file.created ?? .distantFuture,
            path: file.url.path
        )
    }

    struct KeepingOrder: Comparable {
        var mayGo: Int
        var dataGoes: Int
        var looksLikeCopy: Int
        var inDownloads: Int
        var created: Date
        var path: String

        static func < (lhs: KeepingOrder, rhs: KeepingOrder) -> Bool {
            let first = (lhs.mayGo, lhs.dataGoes, lhs.looksLikeCopy, lhs.inDownloads)
            let second = (rhs.mayGo, rhs.dataGoes, rhs.looksLikeCopy, rhs.inDownloads)
            if first != second { return first < second }
            return (lhs.created, lhs.path.count, lhs.path) < (rhs.created, rhs.path.count, rhs.path)
        }
    }

    /// Names Finder and browsers give a second copy: "Report copy", "Report copy 2", "Report (1)", "Report 2".
    static func looksLikeCopy(_ name: String) -> Bool {
        name.range(of: #"( copy( \d+)?| \(\d+\)| \d)$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// The guard's reason, as the sentence a row gives for a copy that stays.
    static func lockedReason(for refusal: String) -> String {
        switch refusal {
        case "a whole top-level folder": "It sits directly in your home folder, which this app leaves as it is"
        case "kept in iCloud": "It is kept in iCloud, where removing it would remove it from every device"
        case "on another disk": "It is on another disk"
        case "on your Never Suggest list": "It is on your Never Suggest list"
        default: "It is \(refusal)"
        }
    }

    // MARK: Progress

    /// Collects progress from several files being read at once and passes it on a few times a second.
    final class Reporter: @unchecked Sendable {
        private let lock = NSLock()
        private var progress = DuplicateProgress()
        private var lastSent = Date.distantPast
        private let send: @Sendable (DuplicateProgress) -> Void

        init(_ send: @escaping @Sendable (DuplicateProgress) -> Void) {
            self.send = send
        }

        func update(_ change: (inout DuplicateProgress) -> Void) {
            lock.lock()
            let stage = progress.stage
            change(&progress)
            let now = Date()
            let isDue = progress.stage != stage || now.timeIntervalSince(lastSent) > 0.15
            if isDue { lastSent = now }
            let current = progress
            lock.unlock()
            if isDue { send(current) }
        }

        /// Sends the last figures and gives them back.
        func finish() -> DuplicateProgress {
            lock.lock()
            let current = progress
            lock.unlock()
            send(current)
            return current
        }
    }
}
