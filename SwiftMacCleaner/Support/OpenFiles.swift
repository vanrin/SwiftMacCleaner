//
//  OpenFiles.swift
//  SwiftMacCleaner
//

import Darwin
import Foundation

/// What this user's running programs have open, or are standing in, under some folders. It is how
/// the app tells what in a temp folder is still in use: a file nobody has written to for days can
/// still be one a program is holding.
///
/// Only this user's programs can be asked. One that belongs to root or to someone else keeps what it
/// has open to itself, so the answer is "not that this app can see", never "certainly not".
nonisolated struct OpenFiles: Sendable {
    /// Open files and working directories, each written the one way `canonical` writes a path.
    private(set) var paths: Set<String> = []

    init(paths: Set<String> = []) {
        self.paths = Set(paths.map(Self.canonical))
    }

    /// Whether a running program has `url` open, something inside it open, or is standing in it.
    func isInUse(_ url: URL) -> Bool {
        let path = Self.canonical(url.standardizedFileURL.path)
        return paths.contains { $0 == path || $0.hasPrefix(path + "/") }
    }

    /// A path the one way it is compared here. /tmp, /var and /etc are links into /private; macOS
    /// reports them with /private in front, and Foundation takes it off again.
    static func canonical(_ path: String) -> String {
        for folder in ["/tmp", "/var", "/etc"] where path == "/private" + folder || path.hasPrefix("/private" + folder + "/") {
            return String(path.dropFirst("/private".count))
        }
        return path
    }

    /// Asks every running program of this user what it has open under `roots`. It takes a few
    /// hundredths of a second, and reads nothing but the list.
    static func snapshot(under roots: [URL]) -> OpenFiles {
        let prefixes = roots.map { canonical($0.standardizedFileURL.path) + "/" }
        guard !prefixes.isEmpty else { return OpenFiles() }
        var found: Set<String> = []
        func note<Buffer>(_ buffer: inout Buffer) {
            let path = withUnsafePointer(to: &buffer) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<Buffer>.size) { canonical(String(cString: $0)) }
            }
            if prefixes.contains(where: path.hasPrefix) { found.insert(path) }
        }

        // Room for more programs than a Mac runs; the call says how much of it was filled.
        var pids = [pid_t](repeating: 0, count: 16_384)
        let filled = Int(proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size)))
        for pid in pids.prefix(max(0, filled)) where pid > 0 {
            var folders = proc_vnodepathinfo()
            if proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &folders, Int32(MemoryLayout<proc_vnodepathinfo>.size)) > 0 {
                note(&folders.pvi_cdir.vip_path)
            }
            let size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
            guard size > 0 else { continue }
            var descriptors = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(size) / MemoryLayout<proc_fdinfo>.size)
            let used = Int(proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &descriptors, size)) / MemoryLayout<proc_fdinfo>.size
            for descriptor in descriptors.prefix(max(0, used)) where descriptor.proc_fdtype == UInt32(PROX_FDTYPE_VNODE) {
                var file = vnode_fdinfowithpath()
                let read = proc_pidfdinfo(pid, descriptor.proc_fd, PROC_PIDFDVNODEPATHINFO, &file, Int32(MemoryLayout<vnode_fdinfowithpath>.size))
                if read > 0 { note(&file.pvip.vip_path) }
            }
        }
        return OpenFiles(paths: found)
    }
}
