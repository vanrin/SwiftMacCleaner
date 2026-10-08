//
//  SnapshotScanner.swift
//  SwiftMacCleaner
//

import Foundation

/// Time Machine's local snapshots, and iPhone and iPad backups kept by Finder.
nonisolated enum SnapshotScanner {
    static let snapshotsItemID = "snapshots.local"
    static let backupMinimumSize: Int64 = 50_000_000

    static func scan(_ context: ScanContext) async -> AreaScanResult {
        var result = AreaScanResult()
        if let finding = localSnapshots(context) { result.findings.append(finding) }
        await deviceBackups(context, into: &result)
        if result.findings.isEmpty, result.unreadable.isEmpty {
            result.skipReason = "No local snapshots or device backups."
        }
        return result
    }

    // MARK: Local snapshots

    private static func localSnapshots(_ context: ScanContext) -> Finding? {
        guard !context.excluded.contains(snapshotsItemID) else { return nil }
        guard let output = Shell.run("/usr/bin/tmutil", ["listlocalsnapshots", "/"], timeout: 20), output.succeeded else {
            return nil
        }
        let dates = snapshotDates(from: output.stdout)
        guard let oldest = dates.min(), let newest = dates.max() else { return nil }
        let count = dates.count
        let item = FindingItem(
            id: snapshotsItemID,
            title: count == 1 ? "1 local snapshot" : "\(count) local snapshots",
            detail: "Oldest \(context.relative(oldest)), newest \(context.relative(newest)). macOS gives no size; they are part of the purgeable space",
            size: 0,
            command: ["/usr/bin/tmutil", "deletelocalsnapshots", "/"],
            preselected: false,
            sizeUnknown: true
        )
        return Finding(
            id: "snapshots.local",
            area: .snapshots,
            tier: .review,
            title: "Time Machine local snapshots",
            summary: "\(item.title) on \(DiskInfo.current(for: context.home).name)",
            explanation: "Time Machine keeps hourly snapshots on this disk while the backup disk is away, and macOS thins them itself when space runs short. This is the one step that asks for your password. A new snapshot is made at the next backup.",
            method: .adminCommand,
            actionTarget: "tmutil deletelocalsnapshots /",
            items: [item]
        )
    }

    /// Dates from lines such as "com.apple.TimeMachine.2026-10-06-120000.local". The header is ignored.
    static func snapshotDates(from output: String) -> [Date] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return output.split(whereSeparator: \.isNewline).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let range = trimmed.range(of: "com.apple.TimeMachine.") else { return nil }
            let stamp = trimmed[range.upperBound...].prefix(17)
            return formatter.date(from: String(stamp))
        }
    }

    // MARK: Device backups

    private static func deviceBackups(_ context: ScanContext, into result: inout AreaScanResult) async {
        let root = context.home.appending(path: "Library/Application Support/MobileSync/Backup")
        let folders: [URL]
        do {
            folders = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
                .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
        } catch where InstallersTrashScanner.isPermissionError(error) {
            result.unreadable.append("iPhone backups")
            return
        } catch {
            return
        }

        let candidates = folders.map { folder -> PathCandidate in
            let info = Files.plist(at: folder.appending(path: "Info.plist"))
            let device = info?["Device Name"] as? String
            let product = info?["Product Name"] as? String
            let date = (info?["Last Backup Date"] as? Date) ?? Files.modificationDate(folder)
            return PathCandidate(
                title: device ?? product.map { "\($0) backup" } ?? "Device backup",
                detail: date.map { "Backed up \(context.relative($0))" } ?? "Device backup",
                url: folder
            )
        }
        let items = await Sizing.items(prefix: "snapshots.backups", from: candidates, minimumSize: backupMinimumSize)
        guard !items.isEmpty else { return }
        result.findings.append(Finding(
            id: "snapshots.backups",
            area: .snapshots,
            tier: .careful,
            title: "iPhone and iPad backups",
            summary: "\(items.count) \(items.count == 1 ? "backup" : "backups") in \(context.tilde(root))",
            explanation: "Full backups of your devices made by Finder. A backup cannot be recreated once it is gone; Finder makes a new one the next time the device is plugged in and backed up. Anything only on an old backup is lost with it.",
            method: .trash,
            actionTarget: context.tilde(root),
            items: items
        ))
    }
}
