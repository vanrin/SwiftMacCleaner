//
//  DemoData.swift
//  Mac Disk Cleaner
//

#if DEBUG
import Foundation

/// Made-up scan results for looking at the screens without scanning a real disk.
/// Launch with `--demo results`, `scanning`, `xcode`, `projects`, `review` or `done`.
nonisolated enum DemoData {
    private static func item(_ prefix: String, _ title: String, _ detail: String, _ gigabytes: Double,
                             hint: String? = nil, command: [String]? = nil) -> FindingItem {
        FindingItem(id: "\(prefix)/\(title)", title: title, detail: detail, size: Int64(gigabytes * 1e9),
                    paths: command == nil ? [URL(fileURLWithPath: "/Users/demo/\(prefix)/\(title)")] : [],
                    command: command, hint: hint)
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
                quitBundleID: "com.apple.dt.Xcode"
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
                id: "android.gradle", area: .android, tier: .safe, title: "Gradle caches",
                summary: "~/.gradle/caches, wrapper distributions and build cache",
                explanation: "Dependencies and build output Gradle has downloaded or produced. The next Gradle sync fetches what it needs again, which makes that first build slower.",
                method: .delete, actionTarget: "~/.gradle/caches, ~/.gradle/wrapper/dists",
                items: [
                    item("android.gradle", "Gradle dependencies and build cache", "Downloaded again on the next Gradle sync", 5.8),
                    item("android.gradle", "Gradle wrapper distributions", "Each Gradle version is downloaded again when a project asks for it", 1.3),
                ]
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
                id: "docker.unused", area: .docker, tier: .review, title: "Docker images and build cache",
                summary: "Unused images, build cache, stopped containers",
                explanation: "Images no container uses, layers kept from earlier builds, and stopped containers. Images are pulled or built again when you need them. Volumes are left alone because they can hold data.",
                method: .command, actionTarget: "docker image prune, docker builder prune, docker container prune",
                items: [
                    item("docker.unused", "Unused images", "12 of 14 images are not used by any container", 9.1, command: ["/usr/local/bin/docker", "image", "prune", "--all", "--force"]),
                    item("docker.unused", "Build cache", "Layers kept from earlier builds", 3.2, command: ["/usr/local/bin/docker", "builder", "prune", "--all", "--force"]),
                    item("docker.unused", "Stopped containers", "6 of 7 containers are not running", 0.4, command: ["/usr/local/bin/docker", "container", "prune", "--force"]),
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
                id: "installers.downloads", area: .installersTrash, tier: .review, title: "Installers in Downloads",
                summary: "3 disk images and installers",
                explanation: "Disk images and installer packages. Once the app is installed these are rarely needed, and they can be downloaded again.",
                method: .trash, actionTarget: "~/Downloads",
                items: [
                    item("installers.downloads", "android-studio-mac_arm.dmg", "Downloaded 5 months ago", 1.4),
                    item("installers.downloads", "Docker.dmg", "Downloaded 3 months ago", 0.8),
                    item("installers.downloads", "Figma.dmg", "Downloaded 8 months ago", 0.6),
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

    /// The result of cleaning every safe finding in `findings`.
    static func outcome(for findings: [Finding], freeBefore: Int64) -> CleanOutcome {
        let steps = findings.filter { $0.tier == .safe }.map {
            StepOutcome(id: $0.id, title: $0.title, method: $0.method, size: $0.size,
                        cleanedItemIDs: $0.items.map(\.id), failures: [], skippedReason: nil)
        }
        let freed = steps.reduce(Int64(0)) { $0 + $1.size }
        return CleanOutcome(steps: steps, freeBefore: freeBefore, freeAfter: freeBefore + freed,
                            trashedSize: 0, duration: 38, logURL: nil)
    }
}
#endif
