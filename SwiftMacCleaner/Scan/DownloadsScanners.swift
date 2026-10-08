//
//  DownloadsScanners.swift
//  SwiftMacCleaner
//

import Foundation

/// The Downloads folder, which two scanners sort through: one for installers, one for large old files.
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

/// Big files that have sat in Downloads untouched for longer than the user's limit.
nonisolated enum LargeFileScanner {
    static let minimumSize: Int64 = 100_000_000

    static func scan(_ context: ScanContext) async -> AreaScanResult {
        guard let files = DownloadsFolder.files(context) else { return .unreadable(DownloadsFolder.name) }
        var candidates: [PathCandidate] = []
        // Installers are Applications' to offer, however old they are.
        for file in files where !InstallerScanner.isInstaller(file) {
            guard let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate, modified < context.largeFileCutoff else { continue }
            candidates.append(PathCandidate(
                title: file.lastPathComponent,
                detail: "\(kind(of: file)), last changed \(context.relative(modified))",
                url: file
            ))
        }
        let items = await Sizing.items(prefix: "largeFiles.downloads", from: candidates, minimumSize: minimumSize)
        guard !items.isEmpty else { return AreaScanResult() }
        return AreaScanResult(findings: [Finding(
            id: "largeFiles.downloads",
            area: .largeFiles,
            tier: .review,
            title: "Large files in Downloads",
            summary: "\(items.count) \(items.count == 1 ? "file" : "files") of \(ByteFormat.string(minimumSize)) or more untouched for \(context.largeFileDays)+ days",
            explanation: "Big downloads you have not opened in a while. They go to the Trash, so they can be put back if one turns out to matter.",
            method: .trash,
            actionTarget: context.tilde(DownloadsFolder.url(context)),
            items: items
        )])
    }

    /// A plain word for what a file is, from its extension.
    static func kind(of file: URL) -> String {
        switch file.pathExtension.lowercased() {
        case "zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar": "Archive"
        case "mov", "mp4", "m4v", "mkv", "avi", "webm": "Video"
        case "mp3", "m4a", "wav", "aac", "flac": "Audio"
        case "pdf": "PDF"
        case "jpg", "jpeg", "png", "heic", "gif", "tiff", "psd", "raw": "Image"
        case "app": "App"
        case "": "File"
        default: file.pathExtension.uppercased() + " file"
        }
    }
}
