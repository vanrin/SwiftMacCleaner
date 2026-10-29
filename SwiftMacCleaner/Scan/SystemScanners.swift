//
//  SystemScanners.swift
//  SwiftMacCleaner
//

import Foundation

/// App caches and logs in the user's Library, app container caches, browser and chat app caches
/// (see `AppDataScanner`), the per-user temp folders, what is this user's in the temp folder every
/// program shares, and the old logs that belong to root.
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
        findings += await AppDataScanner.findings(context)
        // Asked once for every temp folder: what a running program has open is left where it is.
        let openFiles = OpenFiles.snapshot(under: GuardRoots.temporaryFolders())
        let shared = SharedTempScanner.scan(context, openFiles: openFiles)
        if let finding = await temporaryFolders(context, openFiles: openFiles, settled: shared.settled) { findings.append(finding) }
        if let finding = SharedTempScanner.finding(for: shared.idle) { findings.append(finding) }
        if let finding = await logs(context) { findings.append(finding) }
        if let roots = context.systemLogRoots, let finding = await SystemLogs.finding(context, roots: roots) { findings.append(finding) }
        return AreaScanResult(findings: findings, protected: shared.protected)
    }

    private static func appCaches(_ context: ScanContext, ownName: String) async -> Finding? {
        let cacheRoot = context.home.appending(path: "Library/Caches")
        let claimed = Catalog.claimedCacheFolders.union(systemCacheFolders).union(["com.apple.dt.Xcode", ownName])
        let candidates = Files.children(of: cacheRoot)
            .filter { url in
                let name = url.lastPathComponent
                return !name.hasPrefix("com.apple.") && !name.hasPrefix(".") && !claimed.contains(name) && !Files.isSymlink(url)
            }
            .map { PathCandidate(title: displayName($0.lastPathComponent), detail: $0.lastPathComponent, url: $0,
                                 keptBy: $0.lastPathComponent) }
        let items = await Sizing.items(prefix: "caches.apps", from: candidates, minimumSize: 10_000_000)
        guard !items.isEmpty else { return nil }
        return Finding(
            id: "caches.apps",
            area: .cachesLogs,
            aftermath: .rebuilds,
            title: "App caches",
            summary: "\(context.tilde(cacheRoot)) for \(items.count) \(items.count == 1 ? "app" : "apps")",
            explanation: "Temporary files apps keep to start faster. Each app recreates its cache as it runs. macOS's own caches are left alone.",
            method: .delete,
            actionTarget: context.tilde(cacheRoot),
            items: items,
            keepsChanging: true
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
                    url: container.appending(path: "Data/Library/Caches"),
                    keptBy: container.lastPathComponent
                )
            }
        let items = await Sizing.items(prefix: "caches.containers", from: candidates, minimumSize: 10_000_000)
        guard !items.isEmpty else { return nil }
        return Finding(
            id: "caches.containers",
            area: .cachesLogs,
            aftermath: .rebuilds,
            title: "App container caches",
            summary: "\(items.count) sandboxed \(items.count == 1 ? "app" : "apps") in \(context.tilde(containers))",
            explanation: "Caches kept by sandboxed apps inside their own containers. Each app recreates its cache as it runs. Settings and documents in the containers are left alone.",
            method: .delete,
            actionTarget: "~/Library/Containers/*/Data/Library/Caches",
            items: items,
            keepsChanging: true
        )
    }

    /// Items apps left in the per-user folders under /var/folders and then forgot about, together with
    /// what has sat just as long at the top of the temp folder every program shares.
    private static func temporaryFolders(_ context: ScanContext, openFiles: OpenFiles, settled: [FindingItem]) async -> Finding? {
        let cutoff = context.now.addingTimeInterval(-tempIdleDays * 86_400)
        var candidates: [PathCandidate] = []
        for folder in GuardRoots.userTemporaryFolders() {
            let kind = folder.lastPathComponent == "C" ? "cache" : "temp"
            for entry in Files.children(of: folder) where !entry.lastPathComponent.hasPrefix("com.apple.") && !Files.isSymlink(entry) {
                guard let newest = Cleaner.newestChange(in: entry), newest < cutoff, !openFiles.isInUse(entry) else { continue }
                candidates.append(PathCandidate(
                    title: entry.lastPathComponent,
                    detail: "In your \(kind) folder, untouched since \(context.relative(newest))",
                    url: entry
                ))
            }
        }
        let items = (await Sizing.items(prefix: "caches.temp", from: candidates, minimumSize: 10_000_000) + settled)
            .sorted { $0.size > $1.size }
        guard !items.isEmpty else { return nil }
        let shared = GuardRoots.sharedTemporaryFolder.path
        return Finding(
            id: "caches.temp",
            area: .cachesLogs,
            aftermath: .rebuilds,
            title: "Your temp and cache folders",
            summary: "\(items.count) \(items.count == 1 ? "item" : "items") untouched for \(Int(tempIdleDays))+ days under /var/folders and \(shared)",
            explanation: "Files apps left in the per-user temp and cache folders macOS gives you under /var/folders, and what is yours in \(shared), the temp folder every program shares. Only items untouched for a week, with nothing in them open in a running program, are offered; macOS clears the rest on reboot.",
            method: .delete,
            actionTarget: "Your folders under /var/folders, and \(shared)",
            items: items
        )
    }

    private static func logs(_ context: ScanContext) async -> Finding? {
        let logRoot = context.home.appending(path: "Library/Logs")
        let candidates = Files.children(of: logRoot)
            .filter { !$0.lastPathComponent.hasPrefix(".") && $0.lastPathComponent != CleanLog.folderName && !Files.isSymlink($0) }
            .map { PathCandidate(title: displayName($0.lastPathComponent), detail: $0.lastPathComponent, url: $0,
                                 keptBy: $0.lastPathComponent) }
        let items = await Sizing.items(prefix: "caches.logs", from: candidates, minimumSize: 5_000_000)
        guard !items.isEmpty else { return nil }
        return Finding(
            id: "caches.logs",
            area: .cachesLogs,
            aftermath: .rebuilds,
            title: "Logs and crash reports",
            summary: "\(context.tilde(logRoot)), \(items.count) \(items.count == 1 ? "item" : "items")",
            explanation: "Log files and crash reports apps have written. Apps start new logs as they run.",
            method: .delete,
            actionTarget: context.tilde(logRoot),
            items: items,
            keepsChanging: true
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

    /// Whether the item belongs to the user the app runs as. Something root or another user owns can
    /// sit in the Trash too, such as an app an installer put in /Applications, and only Finder can
    /// empty that, with a password.
    static func isOwn(_ url: URL) -> Bool {
        var status = stat()
        return lstat(url.path, &status) == 0 && status.st_uid == getuid()
    }

    static func scan(_ context: ScanContext, isOwn: @Sendable (URL) -> Bool = isOwn) async -> AreaScanResult {
        let trash = context.home.appending(path: ".Trash")
        let everything: [URL]
        do {
            everything = try FileManager.default.contentsOfDirectory(at: trash, includingPropertiesForKeys: nil, options: [])
                .filter { $0.lastPathComponent != ".DS_Store" }
        } catch where Files.isPermissionError(error) {
            return .unreadable("the Trash")
        } catch {
            return AreaScanResult()
        }
        let (entries, foreign) = everything.partitioned(by: isOwn)
        let sizes = await Sizing.sizes(of: everything)
        // What the app could not delete is shown and left out, so the figure is one it can keep.
        var protected: [ProtectedItem] = []
        if !foreign.isEmpty {
            let names = ListFormat.string(foreign.map(\.lastPathComponent).sorted())
            protected.append(ProtectedItem(
                id: "trash.foreign", area: .trash, title: "\(names) in the Trash",
                why: "\(foreign.count == 1 ? "It belongs" : "They belong") to root or another user. Empty the Trash in Finder, which asks for your password",
                rule: .notYours, size: foreign.reduce(0) { $0 + (sizes[$1] ?? 0) }
            ))
        }
        let size = entries.reduce(Int64(0)) { $0 + (sizes[$1] ?? 0) }
        guard size >= minimumSize else { return AreaScanResult(protected: protected) }
        return AreaScanResult(findings: [Finding(
            id: "trash.items",
            area: .trash,
            aftermath: .discarded,
            title: "Items in the Trash",
            summary: "\(entries.count) \(entries.count == 1 ? "item" : "items") waiting to be emptied",
            explanation: "Things you already threw away. Emptying the Trash removes them for good.",
            method: .delete,
            actionTarget: context.tilde(trash),
            items: [FindingItem(
                id: "trash.items/all",
                title: foreign.isEmpty ? "Everything in the Trash" : "Everything in the Trash that is yours",
                detail: "\(entries.count) \(entries.count == 1 ? "item" : "items")",
                size: size,
                paths: entries
            )]
        )], protected: protected)
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
