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
