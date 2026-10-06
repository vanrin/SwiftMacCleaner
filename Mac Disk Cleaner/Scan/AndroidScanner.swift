//
//  AndroidScanner.swift
//  Mac Disk Cleaner
//

import Foundation

nonisolated enum AndroidScanner {
    static func scan(_ context: ScanContext) async -> AreaScanResult {
        var findings: [Finding] = []
        if let finding = await gradleCaches(context) { findings.append(finding) }
        if let finding = await emulators(context) { findings.append(finding) }
        guard !findings.isEmpty else {
            let home = context.home
            let installed = Files.exists(home.appending(path: ".gradle")) || Files.exists(home.appending(path: ".android"))
            return AreaScanResult(skipReason: installed ? nil : "Gradle and the Android SDK are not installed.")
        }
        return AreaScanResult(findings: findings)
    }

    private static func gradleCaches(_ context: ScanContext) async -> Finding? {
        let home = context.home
        let items = await Sizing.items(prefix: "android.gradle", from: [
            PathCandidate(title: "Gradle dependencies and build cache",
                          detail: "Downloaded again on the next Gradle sync",
                          url: home.appending(path: ".gradle/caches")),
            PathCandidate(title: "Gradle wrapper distributions",
                          detail: "Each Gradle version is downloaded again when a project asks for it",
                          url: home.appending(path: ".gradle/wrapper/dists")),
            PathCandidate(title: "Gradle daemon logs",
                          detail: "Logs left by past Gradle daemons",
                          url: home.appending(path: ".gradle/daemon")),
            PathCandidate(title: "Android build cache",
                          detail: "Build output shared between Android projects",
                          url: home.appending(path: ".android/build-cache")),
            PathCandidate(title: "Android SDK cache",
                          detail: "Downloads kept by the SDK tools",
                          url: home.appending(path: ".android/cache")),
        ])
        guard !items.isEmpty else { return nil }
        return Finding(
            id: "android.gradle",
            area: .android,
            tier: .safe,
            title: "Gradle caches",
            summary: "~/.gradle/caches, wrapper distributions and build cache",
            explanation: "Dependencies and build output Gradle has downloaded or produced. The next Gradle sync fetches what it needs again, which makes that first build slower.",
            method: .delete,
            actionTarget: "~/.gradle/caches, ~/.gradle/wrapper/dists",
            items: items
        )
    }

    private static func emulators(_ context: ScanContext) async -> Finding? {
        let home = context.home
        let avdRoot = home.appending(path: ".android/avd")
        let sdk = home.appending(path: "Library/Android/sdk")
        let avds = Files.subdirectories(of: avdRoot).filter { $0.pathExtension == "avd" }

        var usedImages = Set<String>()
        var candidates: [PathCandidate] = []
        var keptCount = 0
        for avd in avds {
            if let image = systemImagePath(forEmulatorAt: avd) { usedImages.insert(image) }
            let name = avd.deletingPathExtension().lastPathComponent
            let started = Files.modificationDate(avd)
            // An emulator that ran recently is in use, not clutter.
            if let started, started > context.staleCutoff {
                keptCount += 1
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
        guard !items.isEmpty else { return nil }
        var note: String?
        if keptCount > 0 {
            let emulators = keptCount == 1 ? "1 emulator" : "\(keptCount) emulators"
            note = "Left out on purpose: \(emulators) used in the last \(context.staleDays) days."
        }
        return Finding(
            id: "android.emulators",
            area: .android,
            tier: .review,
            title: "Android emulators and system images",
            summary: "\(context.tilde(avdRoot)), \(items.count) \(items.count == 1 ? "item" : "items")",
            explanation: "An emulator loses its installed apps and data when removed. System images can be downloaded again from the SDK Manager.",
            method: .trash,
            actionTarget: "\(context.tilde(avdRoot)), \(context.tilde(images))",
            items: items,
            note: note
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
