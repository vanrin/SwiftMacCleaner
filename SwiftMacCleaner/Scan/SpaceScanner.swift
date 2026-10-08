//
//  SpaceScanner.swift
//  SwiftMacCleaner
//

import Foundation

/// A folder or large file in the map of where space went.
nonisolated struct SpaceNode: Identifiable, Sendable {
    let path: String
    let name: String
    let size: Int64
    let isDirectory: Bool
    /// macOS would not let the folder be opened, so what it holds is unknown.
    let isUnreadable: Bool
    /// Something inside could not be read, so `size` is a lower bound.
    let isIncomplete: Bool
    /// The folders and files inside that are big enough to be worth listing, largest first.
    let children: [SpaceNode]

    var id: String { path }

    /// Everything inside that was too small to list on its own.
    var smallerItemsSize: Int64 { max(0, size - children.reduce(0) { $0 + $1.size }) }
}

nonisolated struct SpaceProgress: Sendable, Equatable {
    var measured: Int64 = 0
    var items = 0
    var path = ""
}

/// Measures a whole folder tree in one pass and keeps only the parts big enough to matter.
nonisolated enum SpaceScanner {
    /// Folders and files below this size are folded into their parent's "smaller items".
    static let listingThreshold: Int64 = 20_000_000

    /// Set on files and folders that live in the cloud and have not been downloaded.
    private static let datalessFlag: UInt32 = 0x4000_0000

    private struct Frame {
        var size: Int64 = 0
        var children: [SpaceNode] = []
        var isIncomplete = false
    }

    @concurrent
    static func scan(
        root: URL,
        threshold: Int64 = listingThreshold,
        progress: @escaping @Sendable (SpaceProgress) -> Void = { _ in }
    ) async -> SpaceNode? {
        measure(root: root, threshold: threshold, progress: progress)
    }

    /// Returns `nil` when the root cannot be read or the task is cancelled. Only reads; never follows
    /// symlinks, never leaves the root's volume, and never makes a cloud folder download its contents.
    static func measure(root: URL, threshold: Int64, progress: (SpaceProgress) -> Void) -> SpaceNode? {
        guard let path = strdup(root.path) else { return nil }
        defer { free(path) }
        var arguments: [UnsafeMutablePointer<CChar>?] = [path, nil]
        guard let stream = fts_open(&arguments, FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV, nil) else { return nil }
        defer { fts_close(stream) }

        var frames: [Frame] = []
        var hardLinks = Set<UInt64>()
        var result: SpaceNode?
        var report = SpaceProgress()
        var lastReport = Date()

        while let entry = fts_read(stream) {
            report.items += 1
            if report.items % 4096 == 0 {
                if Task.isCancelled { return nil }
                if Date().timeIntervalSince(lastReport) > 0.15 {
                    lastReport = Date()
                    report.path = String(cString: entry.pointee.fts_path)
                    progress(report)
                }
            }

            let kind = Int32(entry.pointee.fts_info)
            switch kind {
            case FTS_D:
                var frame = Frame()
                if let status = entry.pointee.fts_statp?.pointee {
                    frame.size = Int64(status.st_blocks) * 512
                    if status.st_flags & datalessFlag != 0 {
                        // Listing a cloud-only folder would make macOS fetch it. It takes no space anyway.
                        fts_set(stream, entry, FTS_SKIP)
                    }
                }
                frames.append(frame)

            case FTS_DP, FTS_DNR:
                // FTS_DNR arrives in place of the usual post-order visit when a folder cannot be opened.
                guard let frame = frames.popLast() else { continue }
                let isUnreadable = kind == FTS_DNR
                let isIncomplete = frame.isIncomplete || isUnreadable
                let isRoot = frames.isEmpty
                if isRoot || frame.size >= threshold || (isUnreadable && frames.count <= 2) {
                    let path = String(cString: entry.pointee.fts_path)
                    let node = SpaceNode(
                        path: path, name: lastComponent(of: path), size: frame.size, isDirectory: true,
                        isUnreadable: isUnreadable, isIncomplete: isIncomplete,
                        children: frame.children.sorted { $0.size > $1.size }
                    )
                    if isRoot { result = node } else { frames[frames.count - 1].children.append(node) }
                }
                if !isRoot {
                    frames[frames.count - 1].size += frame.size
                    frames[frames.count - 1].isIncomplete = frames[frames.count - 1].isIncomplete || isIncomplete
                }

            case FTS_F, FTS_SL, FTS_SLNONE, FTS_DEFAULT:
                guard !frames.isEmpty, let status = entry.pointee.fts_statp?.pointee else { continue }
                if kind == FTS_F, status.st_nlink > 1, !hardLinks.insert(UInt64(status.st_ino)).inserted { continue }
                let size = Int64(status.st_blocks) * 512
                frames[frames.count - 1].size += size
                report.measured += size
                if size >= threshold {
                    let path = String(cString: entry.pointee.fts_path)
                    frames[frames.count - 1].children.append(SpaceNode(
                        path: path, name: lastComponent(of: path), size: size, isDirectory: false,
                        isUnreadable: false, isIncomplete: false, children: []
                    ))
                }

            case FTS_NS, FTS_ERR:
                if !frames.isEmpty { frames[frames.count - 1].isIncomplete = true }

            default:
                break
            }
        }
        progress(report)
        return result
    }

    /// A plain-language label for folders whose names say nothing, such as a simulator stored under
    /// its identifier: "iPhone 18 Pro simulator, iOS 27.0".
    static func friendlyName(forFolderAt path: String) -> String? {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        guard url.deletingLastPathComponent().path.hasSuffix("/CoreSimulator/Devices"),
              let device = Files.plist(at: url.appending(path: "device.plist")),
              let name = device["name"] as? String else { return nil }
        let runtime = (device["runtime"] as? String).map(XcodeScanner.runtimeName(fromKey:))
        return runtime.map { "\(name) simulator, \($0)" } ?? "\(name) simulator"
    }

    private static func lastComponent(of path: String) -> String {
        guard let slash = path.lastIndex(of: "/"), path.index(after: slash) < path.endIndex else { return path }
        return String(path[path.index(after: slash)...])
    }
}
