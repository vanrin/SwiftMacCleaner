//
//  LeftoverScanner.swift
//  SwiftMacCleaner
//

import AppKit
import Foundation

/// Support files, containers, caches and preferences left behind by apps that are no longer installed.
///
/// An identifier only counts as gone when Launch Services knows no app with it, no installed app's
/// identifier is a prefix of it (helpers), nothing with it is running, and nothing in its folders
/// has changed for a month. Everything offered goes to the Trash, so it can be put back.
nonisolated enum LeftoverScanner {
    static let idleDays = 30.0
    static let minimumSize: Int64 = 10_000_000
    static let reverseDomains: Set<Substring> = [
        "com", "org", "net", "io", "dev", "app", "co", "me", "us", "de", "uk", "fr", "jp", "ru", "cn", "ai",
        "eu", "ch", "se", "nl", "ca", "au", "tv", "cc", "xyz", "info", "biz",
    ]

    /// The places an app leaves things, with what each one is called on a row.
    private static let folders: [(path: String, kind: String)] = [
        ("Library/Application Support", "Application Support"),
        ("Library/Containers", "Container"),
        ("Library/Caches", "Caches"),
    ]

    static func scan(_ context: ScanContext) async -> AreaScanResult {
        var result = AreaScanResult()
        let ownName = Bundle.main.bundleIdentifier ?? ""
        let installed = installedBundleIDs(home: context.home)
        let cutoff = context.now.addingTimeInterval(-idleDays * 86_400)

        // Everything on disk, grouped by identifier.
        var locations: [String: [(url: URL, kind: String)]] = [:]
        for folder in folders {
            for entry in Files.subdirectories(of: context.home.appending(path: folder.path)) {
                let id = entry.lastPathComponent
                guard looksLikeBundleID(id), !id.hasPrefix("com.apple."), id != ownName else { continue }
                locations[id, default: []].append((entry, folder.kind))
            }
        }
        for (id, _) in locations {
            let preferences = context.home.appending(path: "Library/Preferences/\(id).plist")
            if Files.exists(preferences) { locations[id]?.append((preferences, "Preferences")) }
            let saved = context.home.appending(path: "Library/Saved Application State/\(id).savedState")
            if Files.exists(saved) { locations[id]?.append((saved, "Saved State")) }
        }

        var candidates: [(id: String, urls: [URL], kinds: [String], changed: Date?)] = []
        for (id, entries) in locations {
            guard isOrphan(id: id, installed: installed), !RunningApps.isRunning(bundleID: id),
                  applicationURL(forBundleID: id) == nil else { continue }
            let newest = entries.compactMap { Cleaner.newestChange(in: $0.url) }.max()
            if let newest, newest > cutoff {
                result.protected.append(ProtectedItem(
                    id: "leftovers.recent/\(id)", area: .leftovers, title: CachesLogsScanner.displayName(id),
                    why: "Changed \(context.relative(newest)). Something still writes to it",
                    rule: .recentlyUsed, size: nil
                ))
                continue
            }
            candidates.append((id, entries.map(\.url), entries.map(\.kind), newest))
        }

        let sizes = await Sizing.sizes(of: candidates.flatMap(\.urls))
        var items: [FindingItem] = []
        for candidate in candidates {
            let size = candidate.urls.reduce(Int64(0)) { $0 + (sizes[$1] ?? 0) }
            guard size >= minimumSize else { continue }
            let kinds = orderedUnique(candidate.kinds).joined(separator: ", ")
            let changed = candidate.changed.map { "Last changed \(context.relative($0))" } ?? "Never changed"
            items.append(FindingItem(
                id: "leftovers.apps/\(candidate.id)",
                title: CachesLogsScanner.displayName(candidate.id),
                detail: "\(kinds). \(changed). No installed app has this identifier",
                size: size,
                paths: candidate.urls,
                preselected: false,
                hint: candidate.id
            ))
        }
        items.sort { $0.size > $1.size }

        if !items.isEmpty {
            result.findings.append(Finding(
                id: "leftovers.apps",
                area: .leftovers,
                tier: .review,
                title: "Support files of apps that are no longer installed",
                summary: "\(items.count) \(items.count == 1 ? "app" : "apps") that \(items.count == 1 ? "is" : "are") no longer installed",
                explanation: "Folders in your Library that belong to a bundle identifier no installed app claims. An app is counted as gone only when Launch Services knows nothing with that identifier, the folder is 10 MB or more, and nothing in it changed for 30 days. Reinstalling the app recreates what it needs; settings and documents kept in these folders would be gone.",
                method: .trash,
                actionTarget: "~/Library/Application Support, Containers, Caches, Preferences, Saved Application State",
                items: items
            ))
        }
        if result.findings.isEmpty, result.protected.isEmpty {
            result.skipReason = "Nothing left behind by removed apps."
        }
        return result
    }

    /// "com.example.app" yes; "Google", "Code", "com.x" no.
    static func looksLikeBundleID(_ name: String) -> Bool {
        let parts = name.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 3, let first = parts.first, reverseDomains.contains(first.lowercased()[...]) else { return false }
        return parts.allSatisfy { !$0.isEmpty && !$0.contains(" ") }
    }

    /// Gone unless an installed app has this identifier or one it starts with ("com.foo.app.Helper").
    static func isOrphan(id: String, installed: Set<String>) -> Bool {
        let lower = id.lowercased()
        return !installed.contains { candidate in
            let candidate = candidate.lowercased()
            return lower == candidate || lower.hasPrefix(candidate + ".")
        }
    }

    /// Identifiers of every app bundle in the usual places, read from their Info.plist.
    static func installedBundleIDs(home: URL) -> Set<String> {
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true),
            home.appending(path: "Applications"),
        ]
        var ids = Set<String>()
        for root in roots {
            for entry in Files.children(of: root) {
                var apps = [entry]
                // One level of folders, such as /Applications/Utilities.
                if entry.pathExtension != "app", Files.isDirectory(entry), !Files.isSymlink(entry) {
                    apps = Files.children(of: entry)
                }
                for app in apps where app.pathExtension == "app" {
                    if let id = Files.plist(at: app.appending(path: "Contents/Info.plist"))?["CFBundleIdentifier"] as? String {
                        ids.insert(id)
                    }
                }
            }
        }
        return ids
    }

    /// Launch Services' answer, which also knows apps outside /Applications.
    static func applicationURL(forBundleID id: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
