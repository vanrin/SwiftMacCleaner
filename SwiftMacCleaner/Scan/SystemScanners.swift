//
//  SystemScanners.swift
//  SwiftMacCleaner
//

import Foundation

/// App caches and logs in the user's Library, app container caches, and the per-user temp folders.
nonisolated enum CachesLogsScanner {
    /// System caches that are not named com.apple.* but are still best left to macOS.
    static let systemCacheFolders: Set<String> = [
        "CloudKit", "FamilyCircle", "GameKit", "GeoServices", "PassKit", "Metadata", "TemporaryItems",
        "familycircled", "askpermissiond", "storedownloadd",
    ]
    /// Trailing parts of a bundle identifier that say nothing about which app it is.
    static let genericNameParts: Set<Substring> = [
        "mac", "macos", "osx", "app", "desktop", "client", "helper", "default", "editor",
        "ShipIt", "Updater", "ImageCache",
    ]
    /// How long something in the temp folders must sit untouched before it is offered.
    static let tempIdleDays = 7.0

    static func scan(_ context: ScanContext) async -> AreaScanResult {
        var findings: [Finding] = []
        let ownName = Bundle.main.bundleIdentifier ?? ""

        if let finding = await appCaches(context, ownName: ownName) { findings.append(finding) }
        if let finding = await containerCaches(context, ownName: ownName) { findings.append(finding) }
        if let finding = await temporaryFolders(context) { findings.append(finding) }
        if let finding = await logs(context) { findings.append(finding) }
        return AreaScanResult(findings: findings)
    }

    private static func appCaches(_ context: ScanContext, ownName: String) async -> Finding? {
        let cacheRoot = context.home.appending(path: "Library/Caches")
        let claimed = Catalog.claimedCacheFolders.union(systemCacheFolders).union(["com.apple.dt.Xcode", ownName])
        let candidates = Files.children(of: cacheRoot)
            .filter { url in
                let name = url.lastPathComponent
                return !name.hasPrefix("com.apple.") && !name.hasPrefix(".") && !claimed.contains(name) && !Files.isSymlink(url)
            }
            .map { PathCandidate(title: displayName($0.lastPathComponent), detail: $0.lastPathComponent, url: $0) }
        let items = await Sizing.items(prefix: "caches.apps", from: candidates, minimumSize: 10_000_000)
        guard !items.isEmpty else { return nil }
        return Finding(
            id: "caches.apps",
            area: .cachesLogs,
            tier: .safe,
            title: "App caches",
            summary: "\(context.tilde(cacheRoot)) for \(items.count) \(items.count == 1 ? "app" : "apps")",
            explanation: "Temporary files apps keep to start faster. Each app recreates its cache as it runs. macOS's own caches are left alone.",
            method: .delete,
            actionTarget: context.tilde(cacheRoot),
            items: items
        )
    }

    /// Sandboxed apps keep their cache inside their container rather than in ~/Library/Caches.
    private static func containerCaches(_ context: ScanContext, ownName: String) async -> Finding? {
        let containers = context.home.appending(path: "Library/Containers")
        let candidates = Files.subdirectories(of: containers)
            .filter { !$0.lastPathComponent.hasPrefix("com.apple.") && $0.lastPathComponent != ownName }
            .map { container in
                PathCandidate(
                    title: displayName(container.lastPathComponent),
                    detail: "Container cache for \(container.lastPathComponent)",
                    url: container.appending(path: "Data/Library/Caches")
                )
            }
        let items = await Sizing.items(prefix: "caches.containers", from: candidates, minimumSize: 10_000_000)
        guard !items.isEmpty else { return nil }
        return Finding(
            id: "caches.containers",
            area: .cachesLogs,
            tier: .safe,
            title: "App container caches",
            summary: "\(items.count) sandboxed \(items.count == 1 ? "app" : "apps") in \(context.tilde(containers))",
            explanation: "Caches kept by sandboxed apps inside their own containers. Each app recreates its cache as it runs. Settings and documents in the containers are left alone.",
            method: .delete,
            actionTarget: "~/Library/Containers/*/Data/Library/Caches",
            items: items
        )
    }

    /// Items apps left in the per-user folders under /var/folders and then forgot about.
    private static func temporaryFolders(_ context: ScanContext) async -> Finding? {
        let cutoff = context.now.addingTimeInterval(-tempIdleDays * 86_400)
        var candidates: [PathCandidate] = []
        for folder in GuardRoots.userTemporaryFolders() {
            let kind = folder.lastPathComponent == "C" ? "cache" : "temp"
            for entry in Files.children(of: folder) where !entry.lastPathComponent.hasPrefix("com.apple.") && !Files.isSymlink(entry) {
                guard let newest = Cleaner.newestChange(in: entry), newest < cutoff else { continue }
                candidates.append(PathCandidate(
                    title: entry.lastPathComponent,
                    detail: "In your \(kind) folder, untouched since \(context.relative(newest))",
                    url: entry
                ))
            }
        }
        let items = await Sizing.items(prefix: "caches.temp", from: candidates, minimumSize: 10_000_000)
        guard !items.isEmpty else { return nil }
        return Finding(
            id: "caches.temp",
            area: .cachesLogs,
            tier: .safe,
            title: "Your temp and cache folders",
            summary: "\(items.count) \(items.count == 1 ? "item" : "items") untouched for \(Int(tempIdleDays))+ days under /var/folders",
            explanation: "Files apps left in the per-user temp and cache folders macOS gives you under /var/folders. Only items untouched for a week are offered; macOS clears the rest on reboot.",
            method: .delete,
            actionTarget: "Your folders under /var/folders",
            items: items
        )
    }

    private static func logs(_ context: ScanContext) async -> Finding? {
        let logRoot = context.home.appending(path: "Library/Logs")
        let candidates = Files.children(of: logRoot)
            .filter { !$0.lastPathComponent.hasPrefix(".") && $0.lastPathComponent != CleanLog.folderName && !Files.isSymlink($0) }
            .map { PathCandidate(title: displayName($0.lastPathComponent), detail: $0.lastPathComponent, url: $0) }
        let items = await Sizing.items(prefix: "caches.logs", from: candidates, minimumSize: 5_000_000)
        guard !items.isEmpty else { return nil }
        return Finding(
            id: "caches.logs",
            area: .cachesLogs,
            tier: .safe,
            title: "Logs and crash reports",
            summary: "\(context.tilde(logRoot)), \(items.count) \(items.count == 1 ? "item" : "items")",
            explanation: "Log files and crash reports apps have written. Apps start new logs as they run.",
            method: .delete,
            actionTarget: context.tilde(logRoot),
            items: items
        )
    }

    /// "com.google.Chrome" -> "Chrome", "com.microsoft.VSCode.ShipIt" -> "VSCode"
    static func displayName(_ folderName: String) -> String {
        var parts = folderName.split(separator: ".")
        let reverseDomains: Set<Substring> = ["com", "org", "io", "net", "dev", "app", "co", "me", "us"]
        guard parts.count >= 3, let first = parts.first, reverseDomains.contains(first) else { return folderName }
        while parts.count > 2, let last = parts.last, genericNameParts.contains(last) {
            parts.removeLast()
        }
        return parts.last.map(String.init) ?? folderName
    }
}

/// Whatever is sitting in the Trash.
nonisolated enum TrashScanner {
    static let minimumSize: Int64 = 5_000_000

    static func scan(_ context: ScanContext) async -> AreaScanResult {
        let trash = context.home.appending(path: ".Trash")
        let entries: [URL]
        do {
            entries = try FileManager.default.contentsOfDirectory(at: trash, includingPropertiesForKeys: nil, options: [])
                .filter { $0.lastPathComponent != ".DS_Store" }
        } catch where Files.isPermissionError(error) {
            return .unreadable("the Trash")
        } catch {
            return AreaScanResult()
        }
        let sizes = await Sizing.sizes(of: entries)
        let size = sizes.values.reduce(0, +)
        guard size >= minimumSize else { return AreaScanResult() }
        return AreaScanResult(findings: [Finding(
            id: "trash.items",
            area: .trash,
            tier: .review,
            title: "Items in the Trash",
            summary: "\(entries.count) \(entries.count == 1 ? "item" : "items") waiting to be emptied",
            explanation: "Things you already threw away. Emptying the Trash removes them for good.",
            method: .delete,
            actionTarget: context.tilde(trash),
            items: [FindingItem(
                id: "trash.items/all",
                title: "Everything in the Trash",
                detail: "\(entries.count) \(entries.count == 1 ? "item" : "items")",
                size: size,
                paths: entries
            )]
        )])
    }
}

nonisolated extension AreaScanResult {
    /// What an area reports when macOS kept its one folder private.
    static func unreadable(_ folder: String) -> AreaScanResult {
        AreaScanResult(
            skipReason: "macOS did not let the app read \(folder). Grant Full Disk Access in Privacy & Security, then scan again.",
            unreadable: [folder]
        )
    }
}
