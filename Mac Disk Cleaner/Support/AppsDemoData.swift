//
//  AppsDemoData.swift
//  Mac Disk Cleaner
//

#if DEBUG
import Foundation

/// Made-up apps for looking at the Applications screens without reading or touching a real one.
/// Launch with `--demo apps`, followed by `intro`, `scanning`, `summary`, `manager`, `updater`, `leftovers`,
/// `review`, `removing` or `done`. `--demo apps scan` runs the real scan instead, which only reads.
nonisolated enum AppsDemoData {
    private static let library = URL(fileURLWithPath: "/Users/demo/Library", isDirectory: true)

    private static func app(_ name: String, _ bundleID: String, version: String, megabytes: Double,
                            source: AppSource = .other, openedDaysAgo: Double?, needsPassword: Bool = false,
                            feed: UpdateFeed? = nil, files: [(String, AppFileKind, Double)] = []) -> InstalledApp {
        let url = URL(fileURLWithPath: "/Applications/\(name).app", isDirectory: true)
        let now = Date()
        return InstalledApp(
            url: url, name: name, bundleID: bundleID, version: version, build: version,
            source: source, vendor: AppVendor(bundleID: bundleID),
            lastOpened: openedDaysAgo.map { now.addingTimeInterval(-$0 * 86_400) },
            installed: now.addingTimeInterval(-400 * 86_400),
            needsPassword: needsPassword || source == .appStore, feed: feed ?? (source == .appStore ? .appStore : nil),
            files: [AppFile(url: url, kind: .binaries, size: Int64(megabytes * 1e6))] + files.map { path, kind, size in
                AppFile(url: library.appending(path: path), kind: kind, size: Int64(size * 1e6))
            }
        )
    }

    static func apps() -> [InstalledApp] {
        let feed = UpdateFeed.sparkle(URL(fileURLWithPath: "/dev/null"))
        return [
            app("Harbor", "com.example.harbor", version: "4.31.0", megabytes: 1_840, openedDaysAgo: 0, feed: feed, files: [
                ("Containers/com.example.harbor", .containers, 26_400),
                ("Application Support/Harbor", .supportingFiles, 312),
                ("Caches/com.example.harbor", .caches, 148),
                ("Preferences/com.example.harbor.plist", .preferences, 0.004),
                ("Logs/Harbor", .logs, 21),
                ("LaunchAgents/com.example.harbor.helper.plist", .loginItems, 0.004),
            ]),
            app("Keyframe", "com.example.keyframe", version: "2.8", megabytes: 3_150, source: .appStore, openedDaysAgo: 402, files: [
                ("Containers/com.example.keyframe", .containers, 5_820),
                ("Group Containers/4QX8.com.example.keyframe", .containers, 640),
                ("Application Scripts/com.example.keyframe", .supportingFiles, 0.004),
            ]),
            app("Tally", "com.example.tally", version: "14.4", megabytes: 574, source: .appStore, openedDaysAgo: 18, files: [
                ("Containers/com.example.tally", .containers, 84),
            ]),
            app("Inkwell", "com.example.inkwell", version: "3.2.1", megabytes: 212, openedDaysAgo: 3, feed: feed, files: [
                ("Application Support/Inkwell", .supportingFiles, 96),
                ("Caches/com.example.inkwell", .caches, 31),
                ("Preferences/com.example.inkwell.plist", .preferences, 0.008),
                ("Saved Application State/com.example.inkwell.savedState", .supportingFiles, 0.2),
            ]),
            app("Keynote", "com.apple.iWork.Keynote", version: "14.4", megabytes: 574, source: .appStore, openedDaysAgo: 19, files: [
                ("Containers/com.apple.iWork.Keynote", .containers, 12),
            ]),
            app("Google Chrome", "com.google.Chrome", version: "141.0.7390.55", megabytes: 1_320, openedDaysAgo: 0, files: [
                ("Application Support/Google/Chrome", .supportingFiles, 9_400),
                ("Caches/com.google.Chrome", .caches, 410),
                ("Preferences/com.google.Chrome.plist", .preferences, 0.012),
            ]),
            app("Visual Studio Code", "com.microsoft.VSCode", version: "1.104.2", megabytes: 688, openedDaysAgo: 1, needsPassword: true, files: [
                ("Application Support/Code", .supportingFiles, 1_920),
                ("Caches/com.microsoft.VSCode", .caches, 44),
                ("Caches/com.microsoft.VSCode.ShipIt", .caches, 0.02),
                ("Preferences/com.microsoft.VSCode.plist", .preferences, 0.004),
            ]),
            app("IntelliJ IDEA", "com.jetbrains.intellij", version: "2026.2", megabytes: 3_600, openedDaysAgo: 14, files: [
                ("Caches/JetBrains/IntelliJIdea2026.2", .caches, 520),
                ("Logs/JetBrains/IntelliJIdea2026.2", .logs, 64),
                ("Preferences/com.jetbrains.intellij.plist", .preferences, 0.004),
            ]),
            app("Relay", "com.example.relay", version: "9.42.2", megabytes: 402, openedDaysAgo: 2, feed: feed, files: [
                ("Application Support/Relay", .supportingFiles, 233),
                ("Logs/Relay", .logs, 4),
                ("Logs/DiagnosticReports/Relay-2026-09-14-101502.ips", .crashes, 0.03),
            ]),
            app("Pixel Forge", "com.example.pixelforge", version: "1.0.3", megabytes: 58, openedDaysAgo: 413, files: [
                ("Preferences/com.example.pixelforge.plist", .preferences, 0.004),
            ]),
            app("Sprout VPN", "com.example.sproutvpn", version: "7.4.1", megabytes: 13, openedDaysAgo: nil, needsPassword: true),
            app("Lumen Notes", "com.example.lumen", version: "5.1", megabytes: 341, openedDaysAgo: 26, feed: feed, files: [
                ("Application Support/Lumen Notes", .supportingFiles, 1_150),
                ("HTTPStorages/com.example.lumen", .caches, 0.3),
            ]),
        ]
    }

    static func updates(for apps: [InstalledApp]) -> [AppUpdate] {
        let now = Date()
        let details: [(String, String, Double, Double?, String?)] = [
            ("Tally", "14.5", 21, 412, "This update contains bug fixes and performance improvements."),
            ("Inkwell", "3.3", 6, 96, "• Faster search across notebooks\n• Fixes a crash when exporting very long documents\n• Smaller fixes"),
            ("Relay", "9.43.0", 2, nil, nil),
            ("Keynote", "14.5", 21, 508, "This update contains bug fixes and performance improvements."),
        ]
        return details.compactMap { name, version, daysAgo, megabytes, notes in
            guard let app = apps.first(where: { $0.name == name }) else { return nil }
            return AppUpdate(id: app.id, installedVersion: app.version, newVersion: version,
                             released: now.addingTimeInterval(-daysAgo * 86_400), size: megabytes.map { Int64($0 * 1e6) },
                             notes: notes, feed: app.feed ?? .appStore,
                             storeURL: app.source == .appStore ? URL(string: "macappstore://showUpdatesPage") : nil)
        }
    }

    static func leftovers() -> [Finding] {
        func item(_ prefix: String, _ title: String, _ detail: String, megabytes: Double, hint: String? = nil) -> FindingItem {
            FindingItem(id: "\(prefix)/\(title)", title: title, detail: detail, size: Int64(megabytes * 1e6),
                        paths: [URL(fileURLWithPath: "/Users/demo/\(title)")], preselected: false, hint: hint)
        }
        return [
            Finding(
                id: AppsModel.installersFindingID, area: .installersTrash, tier: .review, title: "Installers in Downloads",
                summary: "4 disk images and installers",
                explanation: "Disk images and installer packages. Once the app is installed these are rarely needed, and they can be downloaded again.",
                method: .trash, actionTarget: "~/Downloads",
                items: [
                    item(AppsModel.installersFindingID, "Harbor-4.31.0-arm64.dmg", "Downloaded 3 weeks ago", megabytes: 612),
                    item(AppsModel.installersFindingID, "Inkwell-3.2.1.dmg", "Downloaded 2 months ago", megabytes: 171),
                    item(AppsModel.installersFindingID, "relay-9.40.pkg", "Downloaded 5 months ago", megabytes: 166),
                    item(AppsModel.installersFindingID, "Xcode_27_beta_4.xip", "Downloaded 4 months ago", megabytes: 3_100),
                ]
            ),
            Finding(
                id: AppsModel.leftoverFilesFindingID, area: .leftovers, tier: .review,
                title: "Support files of apps that are no longer installed", summary: "3 apps that are no longer installed",
                explanation: "Folders in your Library that belong to a bundle identifier no installed app claims. Reinstalling the app recreates what it needs; settings and documents kept in these folders would be gone.",
                method: .trash, actionTarget: "~/Library/Application Support, Containers, Caches, Preferences, Saved Application State",
                items: [
                    item(AppsModel.leftoverFilesFindingID, "sketchpad", "Application Support, Caches. Last changed 8 months ago. No installed app has this identifier", megabytes: 940, hint: "com.example.sketchpad"),
                    item(AppsModel.leftoverFilesFindingID, "moviemaker", "Container. Last changed 1 year ago. No installed app has this identifier", megabytes: 258, hint: "com.example.moviemaker"),
                    item(AppsModel.leftoverFilesFindingID, "tinypdf", "Application Support, Preferences. Last changed 5 months ago. No installed app has this identifier", megabytes: 26, hint: "com.example.tinypdf"),
                ]
            ),
        ]
    }

    /// What a removal would report: every step done, except the ones whose app is open.
    static func outcome(for plan: CleanPlan, blocked: [String: String]) -> CleanOutcome {
        let started = Date()
        let steps = plan.steps.map { step in
            let skipped = blocked[step.id]
            return StepOutcome(
                id: step.id, title: step.title, method: step.method, size: step.size,
                cleanedItemIDs: skipped == nil ? step.operations.map(\.itemID) : [], failures: [], skippedReason: skipped,
                trashed: skipped == nil ? step.operations.compactMap { operation in
                    guard case .trash(let url) = operation.kind else { return nil }
                    return TrashedItem(original: url, inTrash: URL(fileURLWithPath: "/Users/demo/.Trash/\(url.lastPathComponent)"),
                                       size: operation.size)
                } : []
            )
        }
        let free = DiskInfo.current().free
        return CleanOutcome(steps: steps, freeBefore: free, freeAfter: free,
                            trashedSize: steps.flatMap(\.trashed).reduce(0) { $0 + $1.size },
                            duration: 4, logURL: nil, started: started)
    }
}
#endif
