//
//  LargeFileScanner.swift
//  SwiftMacCleaner
//

import AppKit
import Foundation

/// Big files that have sat untouched in Downloads, Documents and Desktop for longer than the user's limit.
///
/// Each folder is walked to the bottom, and what is offered is narrowed twice.
///
/// First by where a file sits. Nothing hidden is looked at, nothing in a project, a repository or a
/// database's folder, and nothing in the project folders named in Settings: build output is Developer
/// Clean Up's to offer, with what it knows about each project, and the rest of a project is not
/// clutter. A folder on the Never Suggest list is not opened at all. Nothing kept in iCloud is offered
/// either, since removing a file there removes it from every device.
///
/// An app, a virtual machine, a video library or any other package is one thing to the user, so it is
/// measured whole and offered whole, never picked apart. The libraries macOS manages are not offered.
///
/// Then by whether anyone still uses it. The latest of three dates has to be past the limit: when the
/// file was last changed, when it or a folder around it was put where it is, and when it was last
/// opened. A file unpacked yesterday from an old archive carries the archive's dates, and a film
/// watched every week is never written to; going by the last change alone would offer both. A file a
/// running program has open is left alone and listed as such.
nonisolated enum LargeFileScanner {
    /// How big a file has to be, unless Settings says otherwise.
    static let minimumSize: Int64 = 100_000_000
    /// Where it looks.
    static let folders = [
        Folder(name: "Downloads", place: "in Downloads", symbol: "arrow.down.circle.fill"),
        Folder(name: "Documents", place: "in Documents", symbol: "doc.fill"),
        Folder(name: "Desktop", place: "on the Desktop", symbol: "menubar.dock.rectangle"),
    ]
    /// Where macOS notes, on the file itself, when it was last opened from Finder or an app.
    static let lastOpenedAttribute = "com.apple.lastuseddate#PS"

    /// One of the folders macOS gives every user: its name there, how a sentence places a file in it,
    /// and the system symbol Finder's sidebar pictures it with.
    struct Folder: Sendable, Equatable {
        var name: String
        var place: String
        var symbol: String
    }

    /// A file or a package big enough, and last changed long enough ago, to be looked at more closely.
    struct Candidate: Sendable, Equatable {
        var path: String
        /// What it takes up on the disk; for a package, everything in it.
        var size: Int64
        /// The last change to it; for a package, to anything in it.
        var modified: Date
        var isPackage = false
    }

    /// What walking one folder gave.
    struct Walk: Sendable {
        var candidates: [Candidate] = []
        /// Folders passed over because the user asked never to be offered anything from them, by path.
        var excluded: [String] = []
        /// macOS would not let the app open the folder.
        var isUnreadable = false
    }

    /// A package the walk is inside of, added up as it goes.
    private struct Package {
        var path: String
        var level: Int
        var size: Int64 = 0
        var newest = 0.0
        /// False when part of it is kept only in the cloud or could not be read, so it cannot be judged whole.
        var isWhole = true
    }

    /// The latest thing that happened to a file, and when.
    struct Touch: Sendable, Equatable {
        enum Kind: String, Sendable {
            case changed = "last changed"
            case added = "added"
            case opened = "last opened"
        }

        var kind: Kind
        var date: Date
    }

    static func scan(_ context: ScanContext, openFiles: OpenFiles? = nil, isInCloud: @Sendable (URL) -> Bool = isInCloud,
                     isRunning: @Sendable (URL) -> Bool = isRunning) async -> AreaScanResult {
        var result = AreaScanResult()
        let roots = folders.map { context.home.appending(path: $0.name) }
        // Asked once for all the folders: what this user's running programs have open in them.
        let openFiles = openFiles ?? OpenFiles.snapshot(under: roots)
        let projectFolders = Set(context.projectRoots.flatMap { [$0.standardizedFileURL.path, $0.resolvingSymlinksInPath().path] })
        let excluded = Set(context.excluded)
        var inCloud: [String] = []

        for (folder, root) in zip(folders, roots) where Files.isDirectory(root) && !Files.isSymlink(root) {
            let name = folder.name
            if context.isExcluded(root) {
                result.protected.append(leftOut(root, context: context))
                continue
            }
            if isInCloud(root) {
                inCloud.append(name)
                result.protected.append(ProtectedItem(
                    id: "largeFiles.cloud/\(root.path)", area: .largeFiles, title: name,
                    why: "Kept in iCloud, where removing a file removes it from every device", rule: .protectedList, size: nil
                ))
                continue
            }
            let walk = walk(root, cutoff: context.largeFileCutoff, minimumSize: context.largeFileSize,
                            leavingOut: projectFolders, excluded: excluded, skipsInstallers: name == DownloadsFolder.name)
            if Task.isCancelled { return AreaScanResult() }
            if walk.isUnreadable {
                result.unreadable.append(name)
                continue
            }
            result.protected += walk.excluded.map { leftOut(URL(fileURLWithPath: $0, isDirectory: true), context: context) }

            let prefix = "largeFiles.\(name.lowercased())"
            var items: [FindingItem] = []
            for candidate in walk.candidates {
                let file = URL(fileURLWithPath: candidate.path, isDirectory: candidate.isPackage)
                // A folder synced by some other service can sit inside one that is not.
                guard !isInCloud(file) else { continue }
                let touch = lastTouch(of: candidate, below: root)
                guard touch.date < context.largeFileCutoff else { continue }
                let parent = file.deletingLastPathComponent()
                // An app can run with none of its files held open, so it is asked about by itself.
                let isOpen = candidate.isPackage && file.pathExtension.lowercased() == "app" && isRunning(file)
                if isOpen || openFiles.isInUse(file) {
                    result.protected.append(ProtectedItem(
                        id: "largeFiles.inUse/\(candidate.path)", area: .largeFiles, title: file.lastPathComponent,
                        why: "In \(context.tilde(parent)). \(isOpen ? "It is open" : "A running program has it open")", rule: .inUse,
                        size: candidate.size
                    ))
                    continue
                }
                // Nothing for a file directly in the folder; "in Recordings/2024" for one further down.
                let inside = parent.path.dropFirst(root.path.count + 1)
                var detail = "\(kind(of: file, isPackage: candidate.isPackage))\(inside.isEmpty ? "" : " in \(inside)"), "
                    + "\(touch.kind.rawValue) \(context.relative(touch.date))"
                if sharesData(candidate) { detail += ". A copy shares its data, so removing this one alone frees little" }
                items.append(FindingItem(id: "\(prefix)/\(candidate.path)", title: file.lastPathComponent, detail: detail,
                                         size: candidate.size, paths: [file]))
            }
            guard !items.isEmpty else { continue }
            items.sort { $0.size > $1.size }
            result.findings.append(Finding(
                id: prefix,
                area: .largeFiles,
                tier: .review,
                title: "Large files \(folder.place)",
                summary: "\(items.count) \(items.count == 1 ? "file" : "files") of \(ByteFormat.string(context.largeFileSize)) or more untouched for \(context.largeFileDays)+ days",
                explanation: "Big files \(folder.place) that have not been changed, moved or opened in a while. Projects are left out. They go to the Trash, so they can be put back if one turns out to matter.",
                method: .trash,
                actionTarget: context.tilde(root),
                items: items
            ))
        }

        if result.findings.isEmpty {
            if !result.unreadable.isEmpty {
                result.skipReason = "macOS did not let the app read \(ListFormat.string(result.unreadable)). Grant Full Disk Access in Privacy & Security, then scan again."
            } else if !inCloud.isEmpty {
                result.skipReason = "\(ListFormat.string(inCloud)) \(inCloud.count == 1 ? "is" : "are") kept in iCloud and left alone. Nothing large and old was found elsewhere."
            }
        }
        return result
    }

    // MARK: Walking

    /// Notes every file and package under `folder` that is big enough and was last changed before
    /// `cutoff`. It follows no links, stays on the folder's own disk, and never makes something kept
    /// only in the cloud download itself. `leavingOut` and `excluded` name folders to pass over whole,
    /// by path; the second kind is reported back.
    static func walk(_ folder: URL, cutoff: Date, minimumSize: Int64 = minimumSize, leavingOut: Set<String> = [],
                     excluded: Set<String> = [], skipsInstallers: Bool = false) -> Walk {
        var walk = Walk()
        guard let path = strdup(folder.path) else { return walk }
        defer { free(path) }
        var arguments: [UnsafeMutablePointer<CChar>?] = [path, nil]
        guard let stream = fts_open(&arguments, FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV, nil) else { return walk }
        defer { fts_close(stream) }

        let limit = cutoff.timeIntervalSince1970
        var package: Package?
        var named: Set<UInt64> = []
        var visited = 0
        while let entry = fts_read(stream) {
            visited += 1
            if visited % 4096 == 0, Task.isCancelled { return Walk() }
            let level = Int(entry.pointee.fts_level)
            let kind = Int32(entry.pointee.fts_info)
            let status = entry.pointee.fts_statp?.pointee

            // Inside a package everything counts toward it, whatever it is called, until the walk leaves it.
            if var open = package {
                // The way out of it: the usual visit, or in its place the word that it could not be opened.
                if level == open.level, kind == FTS_DP || kind == FTS_DNR {
                    package = nil
                    if kind == FTS_DP, open.isWhole, open.size >= minimumSize, open.newest < limit {
                        walk.candidates.append(Candidate(path: open.path, size: open.size,
                                                         modified: Date(timeIntervalSince1970: open.newest), isPackage: true))
                    }
                    continue
                }
                switch kind {
                case FTS_D, FTS_F, FTS_SL, FTS_SLNONE, FTS_DEFAULT:
                    guard let status, status.st_flags & UInt32(SF_DATALESS) == 0 else {
                        open.isWhole = false
                        if kind == FTS_D { fts_set(stream, entry, FTS_SKIP) }
                        break
                    }
                    open.newest = max(open.newest, seconds(status.st_mtimespec))
                    // A file with several names in the package is there once.
                    if kind == FTS_D || status.st_nlink == 1 || named.insert(UInt64(status.st_ino)).inserted {
                        open.size += Int64(status.st_blocks) * 512
                    }
                case FTS_DNR, FTS_ERR, FTS_NS:
                    open.isWhole = false
                default:
                    break
                }
                package = open
                continue
            }

            switch kind {
            case FTS_D:
                guard let status else { continue }
                if status.st_flags & UInt32(SF_DATALESS) != 0 {
                    fts_set(stream, entry, FTS_SKIP)
                    continue
                }
                // The folder itself is walked whatever it holds: a stray package.json in Documents does not make it a project.
                guard level > 0 else { continue }
                let path = String(cString: entry.pointee.fts_path)
                let name = (path as NSString).lastPathComponent
                let ending = (name as NSString).pathExtension.lowercased()
                if name.hasPrefix(".") || DuplicateScanner.skippedFolders.contains(name) || leavingOut.contains(path)
                    || SafetyGuard.protectedExtensions.contains(ending) {
                    fts_set(stream, entry, FTS_SKIP)
                } else if excluded.contains(path) {
                    walk.excluded.append(path)
                    fts_set(stream, entry, FTS_SKIP)
                } else if !ending.isEmpty, isPackage(path) {
                    named = []
                    package = Package(path: path, level: level, size: Int64(status.st_blocks) * 512, newest: seconds(status.st_mtimespec))
                } else if DuplicateScanner.isOwnTree(fts_children(stream, 0)) {
                    fts_set(stream, entry, FTS_SKIP)
                }

            case FTS_F:
                guard let status else { continue }
                // The name is the end of the path. A leading dot marks a hidden file.
                let name = entry.pointee.fts_path.advanced(by: Int(entry.pointee.fts_pathlen) - Int(entry.pointee.fts_namelen))
                guard name.pointee != 0x2E, status.st_flags & UInt32(SF_DATALESS) == 0 else { continue }
                let size = Int64(status.st_blocks) * 512
                let modified = seconds(status.st_mtimespec)
                // A file with a second name somewhere frees nothing when this one goes.
                guard size >= minimumSize, status.st_nlink == 1, modified < limit else { continue }
                let path = String(cString: entry.pointee.fts_path)
                // An installer directly in Downloads is Applications' to offer, however old it is.
                if skipsInstallers, level == 1, InstallerScanner.isInstaller(URL(fileURLWithPath: path)) { continue }
                walk.candidates.append(Candidate(path: path, size: size, modified: Date(timeIntervalSince1970: modified)))

            case FTS_DNR:
                // The folder itself, kept private by macOS or locked by its owner.
                if level == 0, [EACCES, EPERM].contains(entry.pointee.fts_errno) { walk.isUnreadable = true }

            default:
                break
            }
        }
        return walk
    }

    private static func seconds(_ time: timespec) -> Double { Double(time.tv_sec) + Double(time.tv_nsec) / 1e9 }

    /// Whether macOS shows the folder as one thing: an app, a virtual machine, a document that is a folder underneath.
    static func isPackage(_ path: String) -> Bool {
        (try? URL(fileURLWithPath: path, isDirectory: true).resourceValues(forKeys: [.isPackageKey]))?.isPackage == true
    }

    // MARK: Judging

    static func isInCloud(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isUbiquitousItemKey]))?.isUbiquitousItem == true
    }

    /// A folder the user asked never to be offered anything from, as it is listed among what was left
    /// alone: by name, without a size, because it was not looked into.
    static func leftOut(_ folder: URL, context: ScanContext) -> ProtectedItem {
        ProtectedItem(id: "largeFiles.never/\(folder.path)", area: .largeFiles, title: folder.lastPathComponent,
                      why: "\(context.tilde(folder)), with everything in it. On your Never Suggest list", rule: .neverSuggest, size: nil)
    }

    /// Whether the app at `url` is open: this copy of it, not another one with the same name.
    static func isRunning(_ url: URL) -> Bool {
        let path = url.resolvingSymlinksInPath().path
        return NSWorkspace.shared.runningApplications.contains { $0.bundleURL?.resolvingSymlinksInPath().path == path }
    }

    /// The latest of when the file was changed, when it or a folder around it was put where it is, and
    /// when it was last opened.
    static func lastTouch(of candidate: Candidate, below root: URL) -> Touch {
        var touch = Touch(kind: .changed, date: candidate.modified)
        // The file, then each folder it sits in up to the one being scanned: moving a folder leaves the files in it as they were.
        var place = URL(fileURLWithPath: candidate.path)
        for _ in candidate.path.dropFirst(root.path.count).split(separator: "/") {
            if let added = (try? place.resourceValues(forKeys: [.addedToDirectoryDateKey]))?.addedToDirectoryDate, added > touch.date {
                touch = Touch(kind: .added, date: added)
            }
            place.deleteLastPathComponent()
        }
        if let opened = lastOpened(candidate.path), opened > touch.date { touch = Touch(kind: .opened, date: opened) }
        return touch
    }

    /// When the file was last opened from Finder or an app, as macOS notes it on the file.
    static func lastOpened(_ path: String) -> Date? {
        var stamp = timespec()
        let length = MemoryLayout<timespec>.size
        guard getxattr(path, lastOpenedAttribute, &stamp, length, 0, XATTR_NOFOLLOW) == length, stamp.tv_sec > 0 else { return nil }
        return Date(timeIntervalSince1970: Double(stamp.tv_sec))
    }

    /// Whether most of the file's data is also another file's, as when Finder duplicated it.
    static func sharesData(_ candidate: Candidate) -> Bool {
        guard !candidate.isPackage, let storage = FileStorage.read(candidate.path) else { return false }
        return storage.cloneCount > 1 && storage.privateSize < candidate.size / 2
    }

    /// A plain word for what a file or a package is, from its extension.
    static func kind(of file: URL, isPackage: Bool = false) -> String {
        switch file.pathExtension.lowercased() {
        case "zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar": "Archive"
        case "mov", "mp4", "m4v", "mkv", "avi", "webm": "Video"
        case "mp3", "m4a", "wav", "aac", "flac": "Audio"
        case "pdf": "PDF"
        case "jpg", "jpeg", "png", "heic", "gif", "tiff", "psd", "raw": "Image"
        case "app": "App"
        case "pvm", "utm", "vmwarevm": "Virtual machine"
        case "fcpbundle", "imovielibrary": "Video library"
        case "logicx", "band": "Music project"
        case "sparsebundle": "Disk image"
        case "": "File"
        default: file.pathExtension.uppercased() + (isPackage ? " package" : " file")
        }
    }
}
