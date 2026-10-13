//
//  DownloadsScanners.swift
//  SwiftMacCleaner
//

import Foundation

/// The Downloads folder, where installers pile up.
nonisolated enum DownloadsFolder {
    static let name = "Downloads"

    static func url(_ context: ScanContext) -> URL { context.home.appending(path: name) }

    /// The visible entries directly in Downloads. Nil when macOS would not let the app read the folder,
    /// as opposed to the folder simply not being there.
    static func files(_ context: ScanContext) -> [URL]? {
        do {
            return try FileManager.default.contentsOfDirectory(
                at: url(context), includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey], options: [.skipsHiddenFiles]
            )
        } catch where Files.isPermissionError(error) {
            return nil
        } catch {
            return []
        }
    }
}

/// Disk images and installer packages left in Downloads. Applications lists them beside the apps
/// they installed; the clean-up scan does not look at them.
nonisolated enum InstallerScanner {
    static let extensions: Set<String> = ["dmg", "pkg", "iso", "xip", "ipsw"]
    static let minimumSize: Int64 = 5_000_000

    static func isInstaller(_ file: URL) -> Bool { extensions.contains(file.pathExtension.lowercased()) }

    static func scan(_ context: ScanContext) async -> AreaScanResult {
        guard let files = DownloadsFolder.files(context) else { return .unreadable(DownloadsFolder.name) }
        let candidates = files.filter(isInstaller).map { file in
            PathCandidate(
                title: file.lastPathComponent,
                detail: Files.modificationDate(file).map { "Downloaded \(context.relative($0))" } ?? "Installer",
                url: file
            )
        }
        let items = await Sizing.items(prefix: "installers.downloads", from: candidates, minimumSize: minimumSize)
        guard !items.isEmpty else { return AreaScanResult() }
        return AreaScanResult(findings: [Finding(
            id: "installers.downloads",
            area: .installers,
            tier: .review,
            title: "Installers in Downloads",
            summary: "\(items.count) disk \(items.count == 1 ? "image or installer" : "images and installers")",
            explanation: "Disk images and installer packages. Once the app is installed these are rarely needed, and they can be downloaded again.",
            method: .trash,
            actionTarget: context.tilde(DownloadsFolder.url(context)),
            items: items
        )])
    }
}
