//
//  SystemScanners.swift
//  Mac Disk Cleaner
//

import Foundation

/// App caches and logs in the user's Library.
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

    static func scan(_ context: ScanContext) async -> AreaScanResult {
        var findings: [Finding] = []
        let ownName = Bundle.main.bundleIdentifier ?? ""

        let cacheRoot = context.home.appending(path: "Library/Caches")
        let claimed = PackageCacheScanner.claimedCacheFolders.union(systemCacheFolders).union(["com.apple.dt.Xcode", ownName])
        let cacheCandidates = Files.children(of: cacheRoot)
            .filter { url in
                let name = url.lastPathComponent
                return !name.hasPrefix("com.apple.") && !name.hasPrefix(".") && !claimed.contains(name) && !Files.isSymlink(url)
            }
            .map { PathCandidate(title: displayName($0.lastPathComponent), detail: $0.lastPathComponent, url: $0) }
        let caches = await Sizing.items(prefix: "caches.apps", from: cacheCandidates, minimumSize: 10_000_000)
        if !caches.isEmpty {
            findings.append(Finding(
                id: "caches.apps",
                area: .cachesLogs,
                tier: .safe,
                title: "App caches",
                summary: "\(context.tilde(cacheRoot)) for \(caches.count) \(caches.count == 1 ? "app" : "apps")",
                explanation: "Temporary files apps keep to start faster. Each app recreates its cache as it runs. macOS's own caches are left alone.",
                method: .delete,
                actionTarget: context.tilde(cacheRoot),
                items: caches
            ))
        }

        let logRoot = context.home.appending(path: "Library/Logs")
        let logCandidates = Files.children(of: logRoot)
            .filter { !$0.lastPathComponent.hasPrefix(".") && $0.lastPathComponent != CleanLog.folderName && !Files.isSymlink($0) }
            .map { PathCandidate(title: displayName($0.lastPathComponent), detail: $0.lastPathComponent, url: $0) }
        let logs = await Sizing.items(prefix: "caches.logs", from: logCandidates, minimumSize: 5_000_000)
        if !logs.isEmpty {
            findings.append(Finding(
                id: "caches.logs",
                area: .cachesLogs,
                tier: .safe,
                title: "Logs",
                summary: "\(context.tilde(logRoot)), \(logs.count) \(logs.count == 1 ? "item" : "items")",
                explanation: "Log files and crash reports apps have written. Apps start new logs as they run.",
                method: .delete,
                actionTarget: context.tilde(logRoot),
                items: logs
            ))
        }
        return AreaScanResult(findings: findings)
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

/// Installers left in Downloads, and whatever is sitting in the Trash.
nonisolated enum InstallersTrashScanner {
    static let installerExtensions: Set<String> = ["dmg", "pkg", "iso", "xip", "ipsw"]

    static func scan(_ context: ScanContext) async -> AreaScanResult {
        var result = AreaScanResult()
        let fileManager = FileManager.default

        let downloads = context.home.appending(path: "Downloads")
        do {
            let files = try fileManager.contentsOfDirectory(at: downloads, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            let candidates = files
                .filter { installerExtensions.contains($0.pathExtension.lowercased()) }
                .map { file in
                    PathCandidate(
                        title: file.lastPathComponent,
                        detail: Files.modificationDate(file).map { "Downloaded \(context.relative($0))" } ?? "Installer",
                        url: file
                    )
                }
            let items = await Sizing.items(prefix: "installers.downloads", from: candidates, minimumSize: 5_000_000)
            if !items.isEmpty {
                result.findings.append(Finding(
                    id: "installers.downloads",
                    area: .installersTrash,
                    tier: .review,
                    title: "Installers in Downloads",
                    summary: "\(items.count) disk \(items.count == 1 ? "image or installer" : "images and installers")",
                    explanation: "Disk images and installer packages. Once the app is installed these are rarely needed, and they can be downloaded again.",
                    method: .trash,
                    actionTarget: context.tilde(downloads),
                    items: items
                ))
            }
        } catch where isPermissionError(error) {
            result.unreadable.append("Downloads")
        } catch {}

        let trash = context.home.appending(path: ".Trash")
        do {
            let entries = try fileManager.contentsOfDirectory(at: trash, includingPropertiesForKeys: nil, options: [])
                .filter { $0.lastPathComponent != ".DS_Store" }
            let sizes = await Sizing.sizes(of: entries)
            let size = sizes.values.reduce(0, +)
            if size >= 5_000_000 {
                result.findings.append(Finding(
                    id: "installers.trash",
                    area: .installersTrash,
                    tier: .review,
                    title: "Items in the Trash",
                    summary: "\(entries.count) \(entries.count == 1 ? "item" : "items") waiting to be emptied",
                    explanation: "Things you already threw away. Emptying the Trash removes them for good.",
                    method: .delete,
                    actionTarget: context.tilde(trash),
                    items: [FindingItem(
                        id: "installers.trash/all",
                        title: "Everything in the Trash",
                        detail: "\(entries.count) \(entries.count == 1 ? "item" : "items")",
                        size: size,
                        paths: entries
                    )]
                ))
            }
        } catch where isPermissionError(error) {
            result.unreadable.append("the Trash")
        } catch {}

        if result.findings.isEmpty, !result.unreadable.isEmpty {
            result.skipReason = "macOS did not let the app read \(result.unreadable.joined(separator: " or ")). "
                + "Grant Full Disk Access in Privacy & Security, then scan again."
        }
        return result
    }

    /// True when macOS refused access, as opposed to the folder simply not being there.
    static func isPermissionError(_ error: Error) -> Bool {
        let error = error as NSError
        if error.domain == NSCocoaErrorDomain, error.code == NSFileReadNoPermissionError { return true }
        let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError
        return [error, underlying].compactMap { $0 }.contains {
            $0.domain == NSPOSIXErrorDomain && ($0.code == Int(EPERM) || $0.code == Int(EACCES))
        }
    }
}
