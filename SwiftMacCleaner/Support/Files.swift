//
//  Files.swift
//  SwiftMacCleaner
//

import Foundation

nonisolated enum Files {
    static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    static func isSymlink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true
    }

    static func children(of url: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])) ?? []
    }

    /// Real folders directly inside `url`, leaving symlinks out.
    static func subdirectories(of url: URL) -> [URL] {
        children(of: url).filter { isDirectory($0) && !isSymlink($0) }
    }

    static func modificationDate(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    static func plist(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }
}

nonisolated extension Files {
    /// The newest modification date anywhere inside `url`, the item itself included. Stops after
    /// `limit` entries so a huge tree costs a bounded amount; what it has seen by then is returned.
    /// Nil when the item cannot be read.
    static func newestModification(in url: URL, limit: Int = 50_000) -> Date? {
        guard let path = strdup(url.path) else { return nil }
        defer { free(path) }
        var arguments: [UnsafeMutablePointer<CChar>?] = [path, nil]
        guard let stream = fts_open(&arguments, FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV, nil) else { return nil }
        defer { fts_close(stream) }

        var newest: Date?
        var visited = 0
        while let entry = fts_read(stream) {
            visited += 1
            if visited > limit { break }
            let kind = Int32(entry.pointee.fts_info)
            guard kind == FTS_F || kind == FTS_D || kind == FTS_SL || kind == FTS_SLNONE || kind == FTS_DEFAULT,
                  let status = entry.pointee.fts_statp?.pointee else { continue }
            let modified = Date(timeIntervalSince1970: Double(status.st_mtimespec.tv_sec) + Double(status.st_mtimespec.tv_nsec) / 1e9)
            if newest.map({ modified > $0 }) ?? true { newest = modified }
        }
        return newest
    }
}

nonisolated enum FileSizer {
    /// Space a file or a whole folder takes on disk, in bytes. Hard-linked files are counted once.
    static func allocatedSize(of url: URL) -> Int64 {
        guard let path = strdup(url.path) else { return 0 }
        defer { free(path) }
        var arguments: [UnsafeMutablePointer<CChar>?] = [path, nil]
        guard let stream = fts_open(&arguments, FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV, nil) else { return 0 }
        defer { fts_close(stream) }

        var total: Int64 = 0
        var hardLinks = Set<UInt64>()
        var visited = 0
        while let entry = fts_read(stream) {
            visited += 1
            if visited % 4096 == 0, Task.isCancelled { break }
            let kind = Int32(entry.pointee.fts_info)
            guard kind == FTS_F || kind == FTS_D || kind == FTS_SL || kind == FTS_SLNONE || kind == FTS_DEFAULT,
                  let status = entry.pointee.fts_statp?.pointee else { continue }
            if kind == FTS_F, status.st_nlink > 1, !hardLinks.insert(UInt64(status.st_ino)).inserted { continue }
            total += Int64(status.st_blocks) * 512
        }
        return total
    }
}

/// A folder or file a scanner wants measured and offered as one item.
nonisolated struct PathCandidate: Sendable {
    var title: String
    var detail: String
    var url: URL
    /// Removed together with `url` but not worth measuring, such as an emulator's `.ini` file.
    var extraPaths: [URL] = []
    var preselected: Bool? = nil
    var hint: String? = nil
}

nonisolated enum Sizing {
    /// Measures several locations at once, a few at a time so the disk is not flooded.
    @concurrent
    static func sizes(of urls: [URL], limit: Int = 4) async -> [URL: Int64] {
        await withTaskGroup(of: (URL, Int64).self) { group in
            var sizes: [URL: Int64] = [:]
            var pending = urls.makeIterator()
            var running = 0
            while running < limit, let url = pending.next() {
                group.addTask { (url, FileSizer.allocatedSize(of: url)) }
                running += 1
            }
            while let (url, size) = await group.next() {
                sizes[url] = size
                if let url = pending.next() {
                    group.addTask { (url, FileSizer.allocatedSize(of: url)) }
                }
            }
            return sizes
        }
    }

    /// Turns the candidates that exist and are big enough into items, largest first.
    static func items(prefix: String, from candidates: [PathCandidate], minimumSize: Int64 = 1_000_000) async -> [FindingItem] {
        let present = candidates.filter { Files.exists($0.url) }
        let sizes = await sizes(of: present.map(\.url))
        return present.compactMap { candidate -> FindingItem? in
            let size = sizes[candidate.url] ?? 0
            guard size >= minimumSize else { return nil }
            return FindingItem(
                id: "\(prefix)/\(candidate.url.path)",
                title: candidate.title,
                detail: candidate.detail,
                size: size,
                paths: [candidate.url] + candidate.extraPaths,
                preselected: candidate.preselected,
                hint: candidate.hint
            )
        }
        .sorted { $0.size > $1.size }
    }
}
