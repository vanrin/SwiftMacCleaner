//
//  DemoData.swift
//  SwiftMacCleaner
//

#if DEBUG
import Foundation

/// Made-up scan results for looking at the screens without scanning a real disk.
/// Launch with `--demo home`, `scanning`, `results`, `review`, `running` or `done` for the overview's screens, which
/// fill every part; with `system`, `developer` or `downloads` and one of `intro`, `scanning`, `summary`, `quiet`,
/// `manager`, `review`, `cleaning` or `done` for one clean-up, which shows the same findings narrowed to its areas;
/// or with an area's raw name, such as `xcode`, `projects` or `trash`, for its clean-up's manager open on that area.
nonisolated enum DemoData {
    private static func item(_ prefix: String, _ title: String, _ detail: String, _ gigabytes: Double,
                             hint: String? = nil, command: [String]? = nil, preselected: Bool? = nil,
                             sizeUnknown: Bool = false) -> FindingItem {
        FindingItem(id: "\(prefix)/\(title)", title: title, detail: detail, size: Int64(gigabytes * 1e9),
                    paths: command == nil ? [URL(fileURLWithPath: "/Users/demo/\(prefix)/\(title)")] : [],
                    command: command, preselected: preselected, hint: hint, sizeUnknown: sizeUnknown)
    }

    static func findings() -> [Finding] {
        [
            Finding(
                id: "projects.stale", area: .projects, tier: .safe, title: "Stale project dependencies",
                summary: "node_modules, Pods and build folders in 9 projects untouched for 60+ days",
                explanation: "Dependency and build folders inside projects you have stopped touching. Source files are never touched, and each project comes back with the command shown in its row.",
                method: .delete, actionTarget: "Generated folders only, in ~/Code",
                items: [
                    item("projects.stale", "atlas_mobile", "~/Code/atlas_mobile · .dart_tool, build, ios/Pods · last touched 5 months ago", 3.4, hint: "flutter pub get, then pod install"),
                    item("projects.stale", "storefront-web", "~/Code/storefront-web · .next, node_modules · last touched 3 months ago", 2.6, hint: "pnpm install"),
                    item("projects.stale", "ledger-api", "~/Code/ledger-api · .gradle, build · last touched 7 months ago", 2.1, hint: "./gradlew build"),
                    item("projects.stale", "design-tokens", "~/Code/design-tokens · node_modules · last touched 4 months ago", 1.6, hint: "npm install"),
                    item("projects.stale", "rn-kiosk", "~/Code/clients/rn-kiosk · android/build, ios/Pods, node_modules · last touched 9 months ago", 1.5, hint: "yarn install, then pod install"),
                    item("projects.stale", "ml-notebooks", "~/Code/ml-notebooks · .venv · last touched 6 months ago", 1.3, hint: "recreate the virtual environment"),
                    item("projects.stale", "docs-site", "~/Code/docs-site · .next, node_modules · last touched 2 months ago", 1.1, hint: "npm install"),
                    item("projects.stale", "billing-worker", "~/Code/billing-worker · target · last touched 8 months ago", 2.4, hint: "cargo build"),
                    item("projects.stale", "landing-2024", "~/Code/landing-2024 · node_modules · last touched 1 year ago", 1.9, hint: "npm install"),
                ],
                note: "Left out on purpose: 6 projects touched in the last 60 days."
            ),
            Finding(
                id: "xcode.derivedData", area: .xcode, tier: .safe, title: "Xcode DerivedData",
                summary: "~/Library/Developer/Xcode/DerivedData, 6 folders",
                explanation: "Build products and indexes. Xcode recreates them on the next build, which will take longer than usual.",
                method: .delete, actionTarget: "~/Library/Developer/Xcode/DerivedData",
                items: [
                    item("xcode.derivedData", "Runner", "Last built 4 months ago", 3.6),
                    item("xcode.derivedData", "PaymentsSDK", "Last built 7 weeks ago", 2.9),
                    item("xcode.derivedData", "WidgetGallery", "Last built 5 months ago", 2.2),
                    item("xcode.derivedData", "ModuleCache.noindex", "Shared build cache", 1.7),
                    item("xcode.derivedData", "onboarding-prototype", "The project folder no longer exists", 1.4),
                    item("xcode.derivedData", "SymbolCache.noindex", "Shared build cache", 2.4),
                ],
                note: "Left out on purpose: 2 projects built in the last 7 days, 3.8 GB. Their build cache is still saving you time.",
                waitsFor: .xcode
            ),
            Finding(
                id: "xcode.deviceSupport", area: .xcode, tier: .safe, title: "Device support",
                summary: "Debug symbols for 4 OS versions copied from your devices",
                explanation: "Debug symbols copied from devices you plugged in. They are copied again the next time that OS version connects.",
                method: .delete, actionTarget: "~/Library/Developer/Xcode/iOS DeviceSupport",
                items: [
                    item("xcode.deviceSupport", "iOS 17.5 (21F79)", "Older iOS version", 2.6),
                    item("xcode.deviceSupport", "iOS 17.2 (21C62)", "Older iOS version", 2.5),
                    item("xcode.deviceSupport", "iOS 16.7 (20H19)", "Older iOS version", 2.4),
                    item("xcode.deviceSupport", "iOS 16.4 (20E247)", "Older iOS version", 2.3),
                ]
            ),
            Finding(
                id: "xcode.leftovers", area: .xcode, tier: .safe, title: "Preview simulators, device logs and test devices",
                summary: "Preview simulators, iOS device logs",
                explanation: "Simulators Xcode Previews boot on their own, logs copied from devices, and devices cloned for tests. Xcode makes new ones as it needs them.",
                method: .delete, actionTarget: "~/Library/Developer/Xcode/UserData/Previews, iOS Device Logs, XCTestDevices",
                items: [
                    item("xcode.leftovers", "Preview simulators", "Simulator devices booted by Xcode Previews", 1.6),
                    item("xcode.leftovers", "iOS device logs", "Logs copied from devices you plugged in", 0.5),
                ],
                waitsFor: .xcode
            ),
            Finding(
                id: "packages.caches", area: .packageCaches, tier: .safe, title: "Package manager caches",
                summary: "npm cache, pnpm store, Homebrew downloads, CocoaPods cache and 2 more",
                explanation: "Copies of packages your package managers have already downloaded. Anything a project needs is fetched again the next time you install.",
                method: .delete, actionTarget: "Each package manager's cache folder",
                items: [
                    item("packages.caches", "npm cache", "Packages npm has downloaded", 2.1, hint: "~/.npm/_cacache"),
                    item("packages.caches", "pnpm store", "Packages pnpm has downloaded. Installed projects keep working", 1.9, hint: "~/Library/pnpm/store"),
                    item("packages.caches", "Homebrew downloads", "Installers for formulae and casks you already installed", 1.3, hint: "~/Library/Caches/Homebrew"),
                    item("packages.caches", "CocoaPods cache", "Pods downloaded for past installs", 1.2, hint: "~/Library/Caches/CocoaPods"),
                    item("packages.caches", "Dart and Flutter packages", "Packages from pub.dev, fetched again by flutter pub get", 1.1, hint: "~/.pub-cache/hosted"),
                    item("packages.caches", "Yarn cache", "Packages Yarn has downloaded", 0.8, hint: "~/Library/Caches/Yarn"),
                ]
            ),
            Finding(
                id: "packages.homebrew", area: .packageCaches, tier: .safe, title: "Old Homebrew versions",
                summary: "38 outdated formula versions and downloads",
                explanation: "Older versions of formulae Homebrew keeps after an upgrade, and downloads it no longer needs.",
                method: .command, actionTarget: "brew cleanup --prune=all",
                items: [
                    item("packages.homebrew", "Outdated formula versions and downloads", "Sized with brew cleanup -n", 2.4, command: ["/opt/homebrew/bin/brew", "cleanup", "--prune=all"]),
                ]
            ),
            Finding(
                id: "android.gradle", area: .android, tier: .safe, title: "Gradle caches",
                summary: "~/.gradle/caches, wrapper distributions and build cache",
                explanation: "Dependencies and build output Gradle has downloaded or produced. The next Gradle sync fetches what it needs again, which makes that first build slower.",
                method: .delete, actionTarget: "~/.gradle/caches, ~/.gradle/wrapper/dists",
                items: [
                    item("android.gradle", "Gradle dependencies and build cache", "Downloaded again on the next Gradle sync", 5.8),
                    item("android.gradle", "Gradle wrapper distributions", "Each Gradle version is downloaded again when a project asks for it", 1.3),
                ],
                waitsFor: .gradleDaemon
            ),
            Finding(
                id: "ides.vscode", area: .ides, tier: .safe, title: "VS Code caches and logs",
                summary: "Compiled code, Extension downloads, Cache, Logs",
                explanation: "Caches, compiled extension bundles and logs VS Code rebuilds as it runs. Settings and extensions are left alone.",
                method: .delete, actionTarget: "~/Library/Application Support/Code",
                items: [
                    item("ides.vscode", "Compiled code", "Compiled JavaScript, rebuilt on launch", 1.4),
                    item("ides.vscode", "Extension downloads", "Installer packages of extensions you already have", 0.9),
                    item("ides.vscode", "Cache", "Web content cache", 0.6),
                    item("ides.vscode", "Logs", "Logs from past sessions", 0.4),
                ],
                waitsFor: .app(bundleID: "com.microsoft.VSCode", name: "VS Code")
            ),
            Finding(
                id: "caches.apps", area: .cachesLogs, tier: .safe, title: "App caches",
                summary: "~/Library/Caches for 3 apps",
                explanation: "Temporary files apps keep to start faster. Each app recreates its cache as it runs. macOS's own caches are left alone.",
                method: .delete, actionTarget: "~/Library/Caches",
                items: [
                    item("caches.apps", "JetBrains", "JetBrains", 2.2),
                    item("caches.apps", "Chrome", "com.google.Chrome", 1.5),
                    item("caches.apps", "Spotify", "com.spotify.client", 0.9),
                ]
            ),
            Finding(
                id: "snapshots.local", area: .snapshots, tier: .review, title: "Time Machine local snapshots",
                summary: "6 snapshots from the last 3 days",
                explanation: "Copies Time Machine keeps on this disk between backups. macOS thins them itself when space runs short, but it waits until the disk is nearly full to do so. This is the only step that asks for your password.",
                method: .adminCommand, actionTarget: "tmutil deletelocalsnapshots",
                items: [
                    item("snapshots.local", "6 local snapshots", "Taken between yesterday and 3 days ago. macOS does not report their size", 0, command: ["/usr/bin/tmutil", "deletelocalsnapshots", "/"], sizeUnknown: true),
                ]
            ),
            Finding(
                id: "containers.docker", area: .containers, tier: .review, title: "Docker images and build cache",
                summary: "Unused images, build cache, stopped containers",
                explanation: "Images no container uses, layers kept from earlier builds, and stopped containers. Images are pulled or built again when you need them. Volumes are left alone because they can hold data.",
                method: .command, actionTarget: "docker image prune, docker builder prune, docker container prune",
                items: [
                    item("containers.docker", "Unused images", "12 of 14 images are not used by any container", 9.1, command: ["/usr/local/bin/docker", "image", "prune", "--all", "--force"]),
                    item("containers.docker", "Build cache", "Layers kept from earlier builds", 3.2, command: ["/usr/local/bin/docker", "builder", "prune", "--all", "--force"]),
                    item("containers.docker", "Stopped containers", "6 of 7 containers are not running", 0.4, command: ["/usr/local/bin/docker", "container", "prune", "--force"]),
                ]
            ),
            Finding(
                id: "xcode.simulators", area: .xcode, tier: .review, title: "Simulator runtimes and devices",
                summary: "4 items you have not used in 60+ days",
                explanation: "Runtimes and devices you have not used in a while. A runtime is a multi-gigabyte download from Xcode if you need it back, and a deleted device loses its installed apps and data.",
                method: .command, actionTarget: "xcrun simctl delete, xcrun simctl runtime delete",
                items: [
                    item("xcode.simulators", "iOS 16.4 Simulator runtime", "Last used 11 months ago", 4.1, command: ["/usr/bin/xcrun", "simctl", "runtime", "delete", "A"]),
                    item("xcode.simulators", "iOS 17.0 Simulator runtime", "Last used 8 months ago", 3.9, command: ["/usr/bin/xcrun", "simctl", "runtime", "delete", "B"]),
                    item("xcode.simulators", "iPhone 15 Pro (iOS 17.0)", "Simulator device, last used 8 months ago", 2.3, command: ["/usr/bin/xcrun", "simctl", "delete", "C"]),
                    item("xcode.simulators", "12 unavailable devices", "Their runtime is no longer installed, so they cannot boot", 1.1, command: ["/usr/bin/xcrun", "simctl", "delete", "unavailable"]),
                ]
            ),
            Finding(
                id: "models.downloads", area: .models, tier: .review, title: "Model and dataset downloads",
                summary: "Hugging Face hub cache, PyTorch hub",
                explanation: "Models and datasets your tools fetched from a hub. Each one is downloaded again on first use, and some are tens of gigabytes. Nothing here is ticked for you.",
                method: .trash, actionTarget: "~/.cache/huggingface, ~/.cache/torch",
                items: [
                    item("models.downloads", "Hugging Face hub cache", "Models and datasets from huggingface.co", 7.8, hint: "~/.cache/huggingface/hub", preselected: false),
                    item("models.downloads", "PyTorch hub", "Models and weights from torch.hub", 1.4, hint: "~/.cache/torch", preselected: false),
                ]
            ),
            Finding(
                id: "android.emulators", area: .android, tier: .review, title: "Android emulators and system images",
                summary: "~/.android/avd, 3 items",
                explanation: "An emulator loses its installed apps and data when removed. System images can be downloaded again from the SDK Manager.",
                method: .trash, actionTarget: "~/.android/avd, ~/Library/Android/sdk/system-images",
                items: [
                    item("android.emulators", "Pixel 7 API 33 emulator", "Emulator with its apps and data, last changed 7 months ago", 3.3),
                    item("android.emulators", "Pixel 4 API 30 emulator", "Emulator with its apps and data, last changed 1 year ago", 2.1),
                    item("android.emulators", "android-31 system image", "google_apis, arm64-v8a. No emulator uses it", 1.8),
                ]
            ),
            Finding(
                id: "toolchains.unused", area: .toolchains, tier: .review, title: "Unused toolchain versions",
                summary: "4 installed versions that are not your default",
                explanation: "Older JDKs, Node versions and SDKs installed by version managers. A project pinned to one of them would need it installed again.",
                method: .trash, actionTarget: "The version folder shown in each row",
                items: [
                    item("toolchains.unused", "Java 11.0.21-tem", "Installed with SDKMAN, not the current Java version", 0.9, hint: "~/.sdkman/candidates/java/11.0.21-tem"),
                    item("toolchains.unused", "Java 17.0.9-tem", "Installed with SDKMAN, not the current Java version", 0.9, hint: "~/.sdkman/candidates/java/17.0.9-tem"),
                    item("toolchains.unused", "Node v16.20.2", "Installed with nvm, not your default version", 0.7, hint: "~/.nvm/versions/node/v16.20.2"),
                    item("toolchains.unused", "Node v18.19.0", "Installed with nvm, not your default version", 0.6, hint: "~/.nvm/versions/node/v18.19.0"),
                ]
            ),
            Finding(
                id: "ides.oldVersions", area: .ides, tier: .review, title: "Old IDE versions",
                summary: "Settings and caches for IntelliJ IDEA 2024.3",
                explanation: "Settings, caches and logs left by IDE versions you have upgraded past. The current version keeps its own copy.",
                method: .trash, actionTarget: "~/Library/Application Support/JetBrains, ~/Library/Caches/JetBrains",
                items: [
                    item("ides.oldVersions", "IntelliJ IDEA 2024.3", "Settings, caches and logs. IntelliJ IDEA 2025.2 is the newest", 1.8, hint: "~/Library/Caches/JetBrains/IntelliJIdea2024.3"),
                ]
            ),
            Finding(
                id: "largeFiles.downloads", area: .largeFiles, tier: .review, title: "Large files in Downloads",
                summary: "3 files of 100 MB or more untouched for 90+ days",
                explanation: "Big downloads you have not opened in a while. They go to the Trash, so they can be put back if one turns out to matter.",
                method: .trash, actionTarget: "~/Downloads",
                items: [
                    item("largeFiles.downloads", "conference-recording.mov", "Video, last changed 7 months ago", 1.3),
                    item("largeFiles.downloads", "survey-export.zip", "Archive, last changed 5 months ago", 0.9),
                    item("largeFiles.downloads", "design-handoff.zip", "Archive, last changed 1 year ago", 0.6),
                ]
            ),
            Finding(
                id: "trash.items", area: .trash, tier: .review, title: "Items in the Trash",
                summary: "14 items waiting to be emptied",
                explanation: "Things you already threw away. Emptying the Trash removes them for good.",
                method: .delete, actionTarget: "~/.Trash",
                items: [
                    item("trash.items", "Everything in the Trash", "14 items", 2.1),
                ]
            ),
            Finding(
                id: "xcode.oldXcodes", area: .xcode, tier: .careful, title: "Older Xcode versions in Applications",
                summary: "Xcode 16.4 is not the selected version",
                explanation: "Xcode versions other than the one xcode-select points at. A project pinned to an older toolchain would need it installed again from the developer site.",
                method: .trash, actionTarget: "/Applications",
                items: [
                    item("xcode.oldXcodes", "Xcode 16.4", "Xcode 26.0 is the selected version and is never offered", 24.0, hint: "/Applications/Xcode-16.4.app"),
                ]
            ),
            Finding(
                id: "snapshots.backups", area: .snapshots, tier: .careful, title: "iPhone and iPad backups",
                summary: "2 device backups",
                explanation: "Local backups of devices synced with this Mac. Removing one loses everything in it that is not also backed up to iCloud.",
                method: .trash, actionTarget: "~/Library/Application Support/MobileSync/Backup",
                items: [
                    item("snapshots.backups", "iPhone", "Backed up 14 months ago", 12.6),
                    item("snapshots.backups", "iPad", "Backed up 2 years ago", 5.9),
                ]
            ),
            Finding(
                id: "xcode.archives", area: .xcode, tier: .careful, title: "Xcode Archives",
                summary: "3 archives, needed to symbolicate crashes from builds you shipped",
                explanation: "Archives hold the dSYMs for builds you shipped. Without them, crash logs from those builds cannot be symbolicated.",
                method: .trash, actionTarget: "~/Library/Developer/Xcode/Archives",
                items: [
                    item("xcode.archives", "Atlas 2.4.0", "Archived 3 months ago", 1.3),
                    item("xcode.archives", "Atlas 2.3.1", "Archived 6 months ago", 1.1),
                    item("xcode.archives", "Kiosk 1.0.2", "Archived 1 year ago", 0.8),
                ]
            ),
        ]
    }

    /// What a scan found and left alone on purpose.
    static func protected() -> [ProtectedItem] {
        [
            ProtectedItem(id: "p/derived", area: .xcode, title: "DerivedData for 2 projects built this week",
                          why: "Their build cache is still saving you time", rule: .recentlyUsed, size: Int64(3.8e9)),
            ProtectedItem(id: "p/ollama", area: .models, title: "Ollama models",
                          why: "~/.ollama/models, on your Never Suggest list", rule: .neverSuggest, size: Int64(12.0e9)),
            ProtectedItem(id: "p/volumes", area: .containers, title: "Docker volumes",
                          why: "4 volumes. Volumes hold data, so the app never offers them", rule: .shownOnly, size: Int64(9.3e9)),
            ProtectedItem(id: "p/icloud", area: .projects, title: "Thesis and Client-Site in iCloud Drive",
                          why: "Project folders in iCloud are left alone; deleting there deletes everywhere", rule: .protectedList, size: Int64(2.4e9)),
            ProtectedItem(id: "p/sim", area: .xcode, title: "iPhone 17 Pro simulator",
                          why: "Booted right now", rule: .inUse, size: Int64(0.8e9)),
            ProtectedItem(id: "p/defaults", area: .toolchains, title: "Node v22.12.0, Java 21.0.4, Python 3.13.1",
                          why: "Your defaults in nvm, SDKMAN and pyenv", rule: .defaultVersion, size: nil),
        ]
    }

    /// The result of cleaning every safe finding in `findings`, with one group moved to the Trash.
    static func outcome(for findings: [Finding], freeBefore: Int64) -> CleanOutcome {
        let started = Date().addingTimeInterval(-134)
        var steps: [StepOutcome] = findings.filter { $0.tier == .safe }.map { finding in
            var step = StepOutcome(id: finding.id, title: finding.title, method: finding.method, size: finding.size,
                                   cleanedItemIDs: finding.items.map(\.id), failures: [], skippedReason: nil)
            if finding.id == "caches.apps", let last = finding.items.last {
                step.cleanedItemIDs.removeAll { $0 == last.id }
                step.skippedItems[last.id] = "/Users/demo/Library/Caches/com.spotify.client: changed since the scan, so it was left alone"
                step.size -= last.size
            }
            if finding.id == "xcode.derivedData" {
                step.cleanedItemIDs = []
                step.skippedReason = InUseCheck.xcode.skipReason
            }
            return step
        }
        if let downloads = findings.first(where: { $0.id == "largeFiles.downloads" }) {
            let trashed = downloads.items.map {
                TrashedItem(original: URL(fileURLWithPath: "/Users/demo/Downloads/\($0.title)"),
                            inTrash: URL(fileURLWithPath: "/Users/demo/.Trash/\($0.title)"), size: $0.size)
            }
            steps.append(StepOutcome(id: downloads.id, title: downloads.title, method: .trash, size: downloads.size,
                                     cleanedItemIDs: downloads.items.map(\.id), failures: [], skippedReason: nil,
                                     trashed: trashed))
        }
        let freed = steps.filter { $0.skippedReason == nil && $0.method != .trash }.reduce(Int64(0)) { $0 + $1.size }
        let trashedSize = steps.flatMap(\.trashed).reduce(Int64(0)) { $0 + $1.size }
        return CleanOutcome(steps: steps, freeBefore: freeBefore, freeAfter: freeBefore + freed,
                            trashedSize: trashedSize, duration: 134, logURL: nil, started: started)
    }
}
#endif
