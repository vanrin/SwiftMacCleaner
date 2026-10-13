//
//  SystemLogs.swift
//  SwiftMacCleaner
//

import Foundation

/// The logs that belong to root, in the two folders every Mac keeps them in. The scan reads and
/// measures them as the user; removing them takes one script that runs as root, so macOS asks for the
/// password once.
///
/// Root is only ever asked for one thing: to delete the plain files, inside a named folder, that
/// nothing has written to for a week. A folder is never removed, so it keeps its owner and its
/// permissions and whatever writes there carries on. What goes is decided as the script runs, not by
/// a list made at scan time, so a file that turned up or was written to in between is judged then.
///
/// Some of these folders can be written to by more than root: crash reports by every administrator,
/// others by the service that owns them. Something running as the user could swap a folder for a
/// link while root is at work, hoping root follows it elsewhere. So the script trusts no path twice.
/// It steps into a folder, asks the kernel where it now stands, and goes on only when that is the
/// folder it meant to enter; from there it deletes only what lies directly in front of it. `find` is
/// never left to walk a tree by itself, because it can be led astray that way.
nonisolated enum SystemLogs {
    /// One thing root is asked to do.
    struct Target: Sendable, Hashable {
        /// One of the log roots.
        var root: URL
        /// The folder directly inside the root whose old files go, however deep they lie. Nil is the
        /// root's own loose files, and no folder is gone into.
        var folder: String?

        var path: String { folder.map { root.path + "/" + $0 } ?? root.path }
        var url: URL { URL(fileURLWithPath: path, isDirectory: true) }
    }

    /// The folders root may be asked to reach into. Both belong to root and only root may add to them.
    static let roots = [
        URL(fileURLWithPath: "/Library/Logs", isDirectory: true),
        URL(fileURLWithPath: "/private/var/log", isDirectory: true),
    ]

    /// How long a log must sit unwritten before it is offered. A log still being written has a newer
    /// date than this, so nothing a running service has open is taken from under it.
    static let idleDays = 7
    /// A log folder smaller than this is not worth a row.
    static let minimumItemSize: Int64 = 1_000_000
    /// Less than this in all is not worth asking for a password.
    static let minimumSize: Int64 = 10_000_000

    static let findingID = "system.logs"

    // MARK: Scanning

    /// What there is to offer, measured as the user. Folders the user may not read count for nothing,
    /// so the figure is never more than what the scan could see.
    @concurrent
    static func finding(_ context: ScanContext, roots: [URL] = roots) async -> Finding? {
        let cutoff = context.now.addingTimeInterval(-Double(idleDays) * 86_400)
        var items: [FindingItem] = []
        for target in candidates(in: roots) {
            if Task.isCancelled { return nil }
            let measured = measure(target, cutoff: cutoff)
            guard measured.size >= minimumItemSize else { continue }
            let files = measured.count == 1 ? "1 file" : "\(measured.count) files"
            items.append(FindingItem(
                id: "\(findingID)/\(target.path)\(target.folder == nil ? "/*" : "")",
                title: target.folder ?? "Old log files in \(target.path)",
                detail: target.folder == nil
                    ? "\(files) untouched for \(idleDays)+ days"
                    : "\(target.path), \(files) untouched for \(idleDays)+ days",
                size: measured.size,
                paths: [target.url],
                systemTarget: target
            ))
        }
        items.sort { $0.size > $1.size }
        guard items.reduce(0, { $0 + $1.size }) >= minimumSize else { return nil }
        let places = ListFormat.string(roots.map(\.path))
        return Finding(
            id: findingID,
            area: .cachesLogs,
            aftermath: .rebuilds,
            title: "System logs",
            summary: "\(items.count) \(items.count == 1 ? "place" : "places") in \(places)",
            explanation: "Logs macOS and its services have not written to for \(idleDays) days. They belong to root, so macOS asks for your password. Newer logs stay, and so does every folder.",
            method: .adminDelete,
            actionTarget: roots.map(\.path).joined(separator: ", "),
            items: items
        )
    }

    /// Everything the scan measures: each root's loose files, and each folder directly inside one.
    static func candidates(in roots: [URL]) -> [Target] {
        var targets: [Target] = []
        for root in roots {
            targets.append(Target(root: root, folder: nil))
            let names = Files.subdirectories(of: root).map(\.lastPathComponent)
            for name in names.sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending }) {
                targets.append(Target(root: root, folder: name))
            }
        }
        return targets.filter { allows($0, roots: roots) }
    }

    /// The space the target's old files take, and how many of them there are. It counts what the
    /// script would delete: plain files, never anything a link leads to.
    static func measure(_ target: Target, cutoff: Date) -> (size: Int64, count: Int) {
        guard let path = strdup(target.path) else { return (0, 0) }
        defer { free(path) }
        var arguments: [UnsafeMutablePointer<CChar>?] = [path, nil]
        guard let stream = fts_open(&arguments, FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV, nil) else { return (0, 0) }
        defer { fts_close(stream) }

        var size: Int64 = 0
        var count = 0
        var visited = 0
        while let entry = fts_read(stream) {
            visited += 1
            if visited % 4096 == 0, Task.isCancelled { break }
            let kind = Int32(entry.pointee.fts_info)
            let level = Int(entry.pointee.fts_level)
            if kind == FTS_D, level >= 1, target.folder == nil {
                fts_set(stream, entry, FTS_SKIP)
                continue
            }
            guard kind == FTS_F, level >= 1, let status = entry.pointee.fts_statp?.pointee,
                  Date(timeIntervalSince1970: Double(status.st_mtimespec.tv_sec)) < cutoff else { continue }
            size += Int64(status.st_blocks) * 512
            count += 1
        }
        return (size, count)
    }

    // MARK: Removing

    /// Whether root may be asked to carry out `target`: it names one of the roots, by the path the
    /// kernel itself gives that folder, and either nothing more or a real folder directly inside it
    /// with a plain name. A link is refused, and so is anything deeper.
    ///
    /// This stands in for `SafetyGuard`, which keeps to the home folder and refuses all of these.
    static func allows(_ target: Target, roots: [URL] = roots) -> Bool {
        guard roots.contains(where: { $0.path == target.root.path }), physicalPath(of: target.root.path) == target.root.path else {
            return false
        }
        if let folder = target.folder {
            guard !folder.isEmpty, !folder.hasPrefix("."), !folder.contains("/"),
                  !folder.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else { return false }
        }
        var status = stat()
        return lstat(target.path, &status) == 0 && status.st_mode & S_IFMT == S_IFDIR
    }

    /// The path the kernel gives a folder, with every link on the way followed. The script compares
    /// against this, so a root has to be named by it.
    static func physicalPath(of path: String) -> String? {
        guard let resolved = realpath(path, nil) else { return nil }
        defer { free(resolved) }
        return String(cString: resolved)
    }

    /// One script for every target, to run as root. Each target is entered and checked on its own, in
    /// a shell of its own, so one that fails or is refused leaves the others to run. When something
    /// that should have gone is still there, the script says which target, by position, and fails.
    ///
    /// - `old` lists or deletes the old files directly inside the folder the shell stands in. `find`
    ///   reports a file it could not delete only in words, so `sweep` deletes and then looks again.
    /// - `walk` sweeps a folder, then enters each real folder inside it, and goes on only when the
    ///   kernel says it now stands where it meant to. A folder that became a link is left alone.
    static func command(for targets: [Target]) -> [String] {
        var lines = [
            "old() { /usr/bin/find . -maxdepth 1 -type f -mtime +\(idleDays)d \"$@\" 2>/dev/null; }",
            "sweep() { old -delete >/dev/null; [ -z \"$(old -print -quit)\" ]; }",
            "walk() { sweep; rc=$?; for d in ./* ./.[!.]* ./..?*; do if [ -d \"$d\" ] && [ ! -L \"$d\" ]; then "
                + "( cd \"$d\" 2>/dev/null && [ \"$(/bin/pwd -P)\" = \"$1/${d#./}\" ] && walk \"$1/${d#./}\" ) || rc=1; "
                + "fi; done; return $rc; }",
            "failed=''",
        ]
        for (index, target) in targets.enumerated() {
            let path = CleanPlan.quote(target.path)
            let action = target.folder == nil ? "sweep" : "walk \(path)"
            // A folder that is gone has nothing left to delete. One that is there is entered and checked.
            lines.append("if [ -e \(path) ] || [ -L \(path) ]; then "
                         + "( cd \(path) 2>/dev/null && [ \"$(/bin/pwd -P)\" = \(path) ] && \(action) ) || failed=\"$failed \(index)\"; fi")
        }
        lines.append("if [ -n \"$failed\" ]; then echo \"failed:$failed\" >&2; exit 1; fi")
        return ["/bin/sh", "-c", lines.joined(separator: "; ")]
    }

    /// The positions the script reported as unfinished, read from what it wrote before failing.
    static func failedPositions(in errorOutput: String) -> Set<Int> {
        guard let marker = errorOutput.range(of: "failed:") else { return [] }
        let rest = errorOutput[marker.upperBound...].prefix { $0 == " " || $0.isNumber }
        return Set(rest.split(separator: " ").compactMap { Int($0) })
    }
}
