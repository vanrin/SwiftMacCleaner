//
//  AndroidScanner.swift
//  SwiftMacCleaner
//

import Foundation

nonisolated enum AndroidScanner {
    static func scan(_ context: ScanContext) async -> AreaScanResult {
        // Gradle is also asked through GRADLE_USER_HOME, which is how its folder gets moved.
        let gradle = await CatalogScanner.report(for: Catalog.gradle, context: context)
        var result = AreaScanResult(findings: gradle.findings, protected: gradle.protected)
        let emulators = await emulators(context)
        if let finding = emulators.finding { result.findings.append(finding) }
        result.protected += emulators.protected
        if let finding = await snapshots(context) { result.findings.append(finding) }
        if let finding = await olderNDKs(context) { result.findings.append(finding) }
        guard !result.findings.isEmpty else {
            let home = context.home
            let installed = Files.exists(home.appending(path: ".gradle")) || Files.exists(home.appending(path: ".android"))
                || !result.protected.isEmpty
            result.skipReason = installed ? nil : "Gradle and the Android SDK are not installed."
            return result
        }
        return result
    }

    private static func emulators(_ context: ScanContext) async -> (finding: Finding?, protected: [ProtectedItem]) {
        let home = context.home
        let avdRoot = home.appending(path: ".android/avd")
        let sdk = home.appending(path: "Library/Android/sdk")
        let avds = Files.subdirectories(of: avdRoot).filter { $0.pathExtension == "avd" }

        var usedImages = Set<String>()
        var candidates: [PathCandidate] = []
        var protected: [ProtectedItem] = []
        for avd in avds {
            if let image = systemImagePath(forEmulatorAt: avd) { usedImages.insert(image) }
            let name = avd.deletingPathExtension().lastPathComponent
            let started = Files.modificationDate(avd)
            // An emulator that ran recently is in use, not clutter.
            if let started, started > context.staleCutoff {
                protected.append(ProtectedItem(
                    id: "android.emulators/recent/\(name)",
                    area: .android,
                    title: name.replacingOccurrences(of: "_", with: " ") + " emulator",
                    why: "Ran \(context.relative(started))",
                    rule: .recentlyUsed,
                    size: nil
                ))
                continue
            }
            candidates.append(PathCandidate(
                title: name.replacingOccurrences(of: "_", with: " ") + " emulator",
                detail: started.map { "Emulator with its apps and data, last changed \(context.relative($0))" } ?? "Emulator with its apps and data",
                url: avd,
                extraPaths: [avdRoot.appending(path: "\(name).ini")].filter(Files.exists)
            ))
        }

        // system-images/<api level>/<variant>/<abi>
        let images = sdk.appending(path: "system-images")
        for api in Files.subdirectories(of: images) {
            for variant in Files.subdirectories(of: api) {
                for abi in Files.subdirectories(of: variant) {
                    let relative = "system-images/\(api.lastPathComponent)/\(variant.lastPathComponent)/\(abi.lastPathComponent)"
                    guard !usedImages.contains(relative) else { continue }
                    candidates.append(PathCandidate(
                        title: "\(api.lastPathComponent) system image",
                        detail: "\(variant.lastPathComponent), \(abi.lastPathComponent). No emulator uses it",
                        url: abi
                    ))
                }
            }
        }

        let items = await Sizing.items(prefix: "android.emulators", from: candidates, minimumSize: 20_000_000)
        guard !items.isEmpty else { return (nil, protected) }
        var note: String?
        if !protected.isEmpty {
            let emulators = protected.count == 1 ? "1 emulator" : "\(protected.count) emulators"
            note = "Left out on purpose: \(emulators) used in the last \(context.staleDays) days."
        }
        let finding = Finding(
            id: "android.emulators",
            area: .android,
            aftermath: .downloadsAgain,
            title: "Android emulators and system images",
            summary: "\(context.tilde(avdRoot)), \(items.count) \(items.count == 1 ? "item" : "items")",
            explanation: "An emulator loses its installed apps and data when removed. System images can be downloaded again from the SDK Manager.",
            method: .trash,
            actionTarget: "\(context.tilde(avdRoot)), \(context.tilde(images))",
            items: items,
            note: note
        )
        return (finding, protected)
    }

    // MARK: Quick Boot snapshots

    static let snapshotsFindingID = "android.snapshots"
    static let emulatorCheck = InUseCheck.process(pattern: "qemu-system", name: "An Android emulator", remedy: "Close the emulator")

    /// The snapshot each emulator saves when it closes, so the next start can skip booting. Only
    /// `default_boot` is offered: snapshots saved by name are the user's own. Emulators that are
    /// offered whole are left to that finding, and one that ran this week keeps its snapshot unticked.
    static func snapshots(_ context: ScanContext, minimumSize: Int64 = 50_000_000) async -> Finding? {
        let avdRoot = context.home.appending(path: ".android/avd")
        var groups: [PathGroup] = []
        for avd in Files.subdirectories(of: avdRoot) where avd.pathExtension == "avd" {
            let started = Files.modificationDate(avd)
            // Not run for a while: the whole emulator is offered instead.
            guard let started, started > context.staleCutoff else { continue }
            let snapshot = avd.appending(path: "snapshots/default_boot")
            guard Files.isDirectory(snapshot) else { continue }
            let recent = started > context.recentBuildCutoff
            groups.append(PathGroup(
                id: avd.lastPathComponent,
                title: avd.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_", with: " ") + " emulator",
                detail: recent
                    ? "Ran \(context.relative(started)), so its snapshot is still saving you a cold boot"
                    : "Last ran \(context.relative(started))",
                paths: [snapshot],
                preselected: recent ? false : nil
            ))
        }
        let items = await Sizing.items(prefix: snapshotsFindingID, from: groups, minimumSize: minimumSize)
        guard !items.isEmpty else { return nil }
        return Finding(
            id: snapshotsFindingID,
            area: .android,
            aftermath: .rebuilds,
            title: "Emulator Quick Boot snapshots",
            summary: "\(items.count) \(items.count == 1 ? "emulator" : "emulators") in \(context.tilde(avdRoot))",
            explanation: "The memory image an emulator saves when it closes, so it can start in seconds. Without it the next start is a cold boot, which takes longer, and the emulator saves a new snapshot when it closes again. Installed apps and data are left alone.",
            method: .delete,
            actionTarget: "~/.android/avd/*.avd/snapshots/default_boot",
            items: items,
            waitsFor: emulatorCheck
        )
    }

    // MARK: Older NDK versions

    static let ndkFindingID = "android.ndk"

    /// NDK versions installed side by side in the SDK, all but the newest. A project that pins one
    /// gets it again from the Android Gradle plugin, so they go to the Trash and are not ticked.
    static func olderNDKs(_ context: ScanContext, minimumSize: Int64 = 50_000_000) async -> Finding? {
        let ndk = context.home.appending(path: "Library/Android/sdk/ndk")
        let versions = Files.subdirectories(of: ndk).compactMap { folder -> (URL, [Int])? in
            let key = folder.lastPathComponent.split(separator: ".").compactMap { Int($0) }
            return key.isEmpty ? nil : (folder, key)
        }
        guard let newest = versions.map(\.1).max(by: { $0.lexicographicallyPrecedes($1) }) else { return nil }
        let newestName = newest.map(String.init).joined(separator: ".")
        let candidates = versions.filter { $0.1 != newest }.map { folder, _ in
            PathCandidate(title: "NDK \(folder.lastPathComponent)",
                          detail: "Older than NDK \(newestName), which is kept. Downloaded again if a project asks for this version",
                          url: folder, preselected: false)
        }
        let items = await Sizing.items(prefix: ndkFindingID, from: candidates, minimumSize: minimumSize)
        guard !items.isEmpty else { return nil }
        return Finding(
            id: ndkFindingID,
            area: .android,
            aftermath: .downloadsAgain,
            title: "Older Android NDK versions",
            summary: "\(items.count) \(items.count == 1 ? "version" : "versions") besides NDK \(newestName)",
            explanation: "Native development kits installed side by side, each a few gigabytes. The Android Gradle plugin downloads a missing one again when a project pins it with ndkVersion. They go to the Trash and nothing here is ticked for you.",
            method: .trash,
            actionTarget: context.tilde(ndk),
            items: items
        )
    }

    /// Reads `image.sysdir.1` from an emulator's config, such as "system-images/android-34/google_apis/arm64-v8a".
    static func systemImagePath(forEmulatorAt avd: URL) -> String? {
        guard let config = try? String(contentsOf: avd.appending(path: "config.ini"), encoding: .utf8) else { return nil }
        for line in config.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, parts[0] == "image.sysdir.1" else { continue }
            return parts[1]
                .replacingOccurrences(of: "\\", with: "/")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return nil
    }
}
