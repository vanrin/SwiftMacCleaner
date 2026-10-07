//
//  Catalog.swift
//  Mac Disk Cleaner
//
//  One reviewed list of every fixed location the app may offer. Scanners that only need
//  "measure these folders and offer the big ones" read their entries from here, so a new
//  cache is one line, and a test can walk the whole list past the safety guard.
//

import Foundation

/// A folder with a fixed place in the home folder.
nonisolated struct KnownLocation: Sendable {
    var title: String
    var detail: String
    /// Relative to home.
    var path: String
    var preselected: Bool? = nil
    var hint: String? = nil

    init(_ title: String, _ path: String, _ detail: String, preselected: Bool? = nil, hint: String? = nil) {
        self.title = title
        self.path = path
        self.detail = detail
        self.preselected = preselected
        self.hint = hint ?? "~/" + path
    }
}

/// A finding made entirely of known locations.
nonisolated struct LocationGroup: Sendable {
    var id: String
    var area: Area
    var tier: SafetyTier
    var method: CleanMethod
    var title: String
    var explanation: String
    var actionTarget: String
    var minimumSize: Int64 = 5_000_000
    var waitsFor: InUseCheck? = nil
    var locations: [KnownLocation]

    /// The first few titles, for the summary line.
    func summary(of items: [FindingItem]) -> String {
        let names = items.prefix(4).map(\.title).joined(separator: ", ")
        return names + (items.count > 4 ? " and \(items.count - 4) more" : "")
    }
}

nonisolated enum Catalog {
    static let packageCaches = LocationGroup(
        id: "packages.caches", area: .packageCaches, tier: .safe, method: .delete,
        title: "Package manager caches",
        explanation: "Copies of packages your package managers have already downloaded. Anything a project needs is fetched again the next time you install.",
        actionTarget: "Each package manager's cache folder",
        locations: [
            KnownLocation("npm cache", ".npm/_cacache", "Packages npm has downloaded"),
            KnownLocation("npx cache", ".npm/_npx", "Packages npx fetched to run once"),
            KnownLocation("npm logs", ".npm/_logs", "Logs from past npm runs"),
            KnownLocation("pnpm store", "Library/pnpm/store", "Packages pnpm has downloaded. Installed projects keep working"),
            KnownLocation("pnpm cache", "Library/Caches/pnpm", "Metadata pnpm has fetched"),
            KnownLocation("Yarn cache", "Library/Caches/Yarn", "Packages Yarn has downloaded"),
            KnownLocation("Yarn Berry cache", ".yarn/berry/cache", "Packages Yarn has downloaded"),
            KnownLocation("Bun cache", ".bun/install/cache", "Packages Bun has downloaded"),
            KnownLocation("Corepack cache", ".cache/node/corepack", "Package manager builds Corepack has downloaded"),
            KnownLocation("Deno cache", "Library/Caches/deno", "Modules Deno has downloaded"),
            KnownLocation("CocoaPods cache", "Library/Caches/CocoaPods", "Pods downloaded for past installs"),
            KnownLocation("CocoaPods master specs", ".cocoapods/repos/master",
                          "The old full clone of the specs repo. CocoaPods now uses the much smaller trunk CDN instead",
                          preselected: false),
            KnownLocation("Dart and Flutter packages", ".pub-cache/hosted", "Packages from pub.dev, fetched again by flutter pub get"),
            KnownLocation("Dart packages from Git", ".pub-cache/git", "Git dependencies, cloned again by flutter pub get"),
            KnownLocation("Homebrew downloads", "Library/Caches/Homebrew", "Installers for formulae and casks you already installed"),
            KnownLocation("pip cache", "Library/Caches/pip", "Wheels pip has downloaded or built"),
            KnownLocation("pip cache", ".cache/pip", "Wheels pip has downloaded or built"),
            KnownLocation("uv cache", ".cache/uv", "Packages uv has downloaded or built"),
            KnownLocation("Poetry cache", "Library/Caches/pypoetry", "Packages Poetry has downloaded"),
            KnownLocation("Poetry cache", ".cache/pypoetry", "Packages Poetry has downloaded"),
            KnownLocation("conda packages", ".conda/pkgs", "Packages conda has downloaded. Environments keep their own copies"),
            KnownLocation("Miniconda packages", "miniconda3/pkgs", "Packages conda has downloaded. Environments keep their own copies"),
            KnownLocation("Anaconda packages", "anaconda3/pkgs", "Packages conda has downloaded. Environments keep their own copies"),
            KnownLocation("Swift Package Manager cache", "Library/Caches/org.swift.swiftpm", "Package checkouts, cloned again when resolved"),
            KnownLocation("Carthage cache", "Library/Caches/org.carthage.CarthageKit", "Dependencies Carthage has built"),
            KnownLocation("Cargo registry", ".cargo/registry", "Crates downloaded from crates.io"),
            KnownLocation("Cargo Git checkouts", ".cargo/git", "Git dependencies, cloned again by cargo build"),
            KnownLocation("Go build cache", "Library/Caches/go-build", "Compiled packages, rebuilt on the next go build"),
            KnownLocation("Composer cache", ".composer/cache", "PHP packages Composer has downloaded"),
            KnownLocation("Composer cache", "Library/Caches/composer", "PHP packages Composer has downloaded"),
            KnownLocation("RubyGems specs", ".gem/specs", "Gem index files, fetched again by gem and bundle"),
            KnownLocation("Bundler cache", ".bundle/cache", "Gems Bundler has downloaded"),
            KnownLocation("NuGet packages", ".nuget/packages",
                          "Packages NuGet has downloaded. Restored again on the next dotnet restore", preselected: false),
            KnownLocation("Playwright browsers", "Library/Caches/ms-playwright", "Browsers downloaded for tests"),
            KnownLocation("Cypress binaries", "Library/Caches/Cypress", "Cypress versions downloaded for tests"),
            KnownLocation("Puppeteer browsers", ".cache/puppeteer", "Browsers downloaded for automation"),
            KnownLocation("Electron downloads", "Library/Caches/electron", "Electron builds downloaded by npm"),
            KnownLocation("node-gyp headers", "Library/Caches/node-gyp", "Node headers for building native modules"),
            KnownLocation("Turborepo cache", "Library/Caches/turbo", "Remote cache artefacts Turborepo has fetched"),
            KnownLocation("Maven repository", ".m2/repository",
                          "Downloaded again by Maven, except anything you installed locally with mvn install",
                          preselected: false),
        ]
    )

    static let goModules = LocationGroup(
        id: "packages.goModules", area: .packageCaches, tier: .review, method: .trash,
        title: "Go module cache",
        explanation: "Every Go module you have ever built against. The next go build downloads what the project needs again, which can take a while on a slow connection.",
        actionTarget: "~/go/pkg/mod",
        minimumSize: 50_000_000,
        locations: [KnownLocation("Go modules", "go/pkg/mod", "Downloaded again on the next go build or go mod download")]
    )

    static let gradle = LocationGroup(
        id: "android.gradle", area: .android, tier: .safe, method: .delete,
        title: "Gradle caches",
        explanation: "Dependencies and build output Gradle has downloaded or produced. The next Gradle sync fetches what it needs again, which makes that first build slower.",
        actionTarget: "~/.gradle/caches, ~/.gradle/wrapper/dists",
        minimumSize: 1_000_000,
        waitsFor: .gradleDaemon,
        locations: [
            KnownLocation("Gradle dependencies and build cache", ".gradle/caches", "Downloaded again on the next Gradle sync"),
            KnownLocation("Gradle wrapper distributions", ".gradle/wrapper/dists", "Each Gradle version is downloaded again when a project asks for it"),
            KnownLocation("Gradle daemon logs", ".gradle/daemon", "Logs left by past Gradle daemons"),
            KnownLocation("Android build cache", ".android/build-cache", "Build output shared between Android projects"),
            KnownLocation("Android SDK cache", ".android/cache", "Downloads kept by the SDK tools"),
        ]
    )

    static let xcodeCaches = LocationGroup(
        id: "xcode.caches", area: .xcode, tier: .safe, method: .delete,
        title: "Xcode caches",
        explanation: "Temporary files Xcode and the simulators recreate when they need them.",
        actionTarget: "~/Library/Caches/com.apple.dt.Xcode, ~/Library/Developer/CoreSimulator/Caches",
        minimumSize: 20_000_000,
        locations: [
            KnownLocation("Xcode cache", "Library/Caches/com.apple.dt.Xcode", "Downloads and temporary files Xcode keeps around"),
            KnownLocation("Simulator caches", "Library/Developer/CoreSimulator/Caches", "Shared caches the simulators rebuild when they boot"),
            KnownLocation("Documentation cache", "Library/Developer/Xcode/DocumentationCache", "Indexed documentation, built again when you open the viewer"),
        ]
    )

    static let xcodeLeftovers = LocationGroup(
        id: "xcode.leftovers", area: .xcode, tier: .safe, method: .delete,
        title: "Preview simulators, device logs and test devices",
        explanation: "Simulators Xcode Previews boot on their own, logs copied from devices, and devices cloned for tests. Xcode makes new ones as it needs them.",
        actionTarget: "~/Library/Developer/Xcode/UserData/Previews, iOS Device Logs, XCTestDevices",
        minimumSize: 20_000_000,
        waitsFor: .xcode,
        locations: [
            KnownLocation("Preview simulators", "Library/Developer/Xcode/UserData/Previews", "Simulator devices booted by Xcode Previews"),
            KnownLocation("iOS device logs", "Library/Developer/Xcode/iOS Device Logs", "Logs copied from devices you plugged in"),
            KnownLocation("Test devices", "Library/Developer/XCTestDevices", "Simulator clones made for parallel tests"),
            KnownLocation("Build products", "Library/Developer/Xcode/Products", "Products exported by older Xcode workflows"),
            KnownLocation("Interface Builder support", "Library/Developer/Xcode/UserData/IB Support", "Simulators Interface Builder uses to render storyboards"),
        ]
    )

    static let modelDownloads = LocationGroup(
        id: "models.downloads", area: .models, tier: .review, method: .trash,
        title: "Model and dataset downloads",
        explanation: "Models and datasets your tools fetched from a hub. Each one is downloaded again on first use, and some are tens of gigabytes. Nothing here is ticked for you.",
        actionTarget: "~/.cache/huggingface, ~/.cache/torch, ~/.lmstudio and friends",
        minimumSize: 100_000_000,
        locations: [
            KnownLocation("Hugging Face hub cache", ".cache/huggingface/hub", "Models and datasets from huggingface.co", preselected: false),
            KnownLocation("Hugging Face datasets", ".cache/huggingface/datasets", "Processed datasets", preselected: false),
            KnownLocation("PyTorch hub", ".cache/torch", "Models and weights from torch.hub", preselected: false),
            KnownLocation("LM Studio models", ".lmstudio/models", "Models downloaded in LM Studio", preselected: false),
            KnownLocation("LM Studio models", ".cache/lm-studio/models", "Models downloaded in LM Studio", preselected: false),
            KnownLocation("Whisper models", ".cache/whisper", "Speech models downloaded by Whisper", preselected: false),
            KnownLocation("Keras models", ".keras/models", "Models Keras has downloaded", preselected: false),
            KnownLocation("Keras datasets", ".keras/datasets", "Datasets Keras has downloaded", preselected: false),
            KnownLocation("Ollama models", ".ollama/models", "Models pulled with ollama. Pull them again when you need them", preselected: false),
        ]
    )

    static let editorCaches: [LocationGroup] = [
        LocationGroup(
            id: "ides.vscode", area: .ides, tier: .safe, method: .delete,
            title: "VS Code caches and logs",
            explanation: "Caches, compiled extension bundles and logs VS Code rebuilds as it runs. Settings and extensions are left alone.",
            actionTarget: "~/Library/Application Support/Code",
            waitsFor: .app(bundleID: "com.microsoft.VSCode", name: "VS Code"),
            locations: Self.electronEditor("Code")
        ),
        LocationGroup(
            id: "ides.cursor", area: .ides, tier: .safe, method: .delete,
            title: "Cursor caches and logs",
            explanation: "Caches, compiled extension bundles and logs Cursor rebuilds as it runs. Settings and extensions are left alone.",
            actionTarget: "~/Library/Application Support/Cursor",
            waitsFor: .app(bundleID: "com.todesktop.230313mzl4w4u92", name: "Cursor"),
            locations: Self.electronEditor("Cursor")
        ),
        LocationGroup(
            id: "ides.windsurf", area: .ides, tier: .safe, method: .delete,
            title: "Windsurf caches and logs",
            explanation: "Caches, compiled extension bundles and logs Windsurf rebuilds as it runs. Settings and extensions are left alone.",
            actionTarget: "~/Library/Application Support/Windsurf",
            waitsFor: .app(bundleID: "com.exafunction.windsurf", name: "Windsurf"),
            locations: Self.electronEditor("Windsurf")
        ),
    ]

    private static func electronEditor(_ folder: String) -> [KnownLocation] {
        let base = "Library/Application Support/\(folder)"
        return [
            KnownLocation("Cache", "\(base)/Cache", "Web content cache"),
            KnownLocation("Compiled code", "\(base)/CachedData", "Compiled JavaScript, rebuilt on launch"),
            KnownLocation("Extension downloads", "\(base)/CachedExtensionVSIXs", "Installer packages of extensions you already have"),
            KnownLocation("Code cache", "\(base)/Code Cache", "Compiled JavaScript, rebuilt on launch"),
            KnownLocation("GPU cache", "\(base)/GPUCache", "Shader cache"),
            KnownLocation("Dawn caches", "\(base)/DawnGraphiteCache", "Graphics shader cache"),
            KnownLocation("Dawn caches", "\(base)/DawnWebGPUCache", "Graphics shader cache"),
            KnownLocation("Logs", "\(base)/logs", "Logs from past sessions"),
            KnownLocation("Crash reports", "\(base)/Crashpad", "Crash dumps waiting to be sent"),
        ]
    }

    static let containerCaches = LocationGroup(
        id: "containers.caches", area: .containers, tier: .safe, method: .delete,
        title: "Kubernetes and VM tool caches",
        explanation: "Images and installers minikube, kind and Lima have downloaded. Fetched again the next time a cluster or machine starts.",
        actionTarget: "~/.minikube/cache, ~/.lima/_cache",
        minimumSize: 20_000_000,
        locations: [
            KnownLocation("minikube image cache", ".minikube/cache", "Kubernetes images and ISOs minikube has downloaded"),
            KnownLocation("Lima downloads", ".lima/_cache", "VM images Lima and Colima have downloaded"),
        ]
    )

    /// Every group, so a test can check each entry against the guard.
    static let allGroups: [LocationGroup] = [
        packageCaches, goModules, gradle, xcodeCaches, xcodeLeftovers, modelDownloads, containerCaches,
    ] + editorCaches

    /// Folders in ~/Library/Caches that a group claims, so the general cache scan leaves them to it.
    static let claimedCacheFolders: Set<String> = Set(allGroups.flatMap(\.locations).compactMap { location in
        let prefix = "Library/Caches/"
        guard location.path.hasPrefix(prefix) else { return nil }
        return String(location.path.dropFirst(prefix.count).split(separator: "/").first ?? "")
    })
}

/// Measures a group's locations and offers the ones that exist and are big enough.
nonisolated enum CatalogScanner {
    static func finding(for group: LocationGroup, context: ScanContext) async -> Finding? {
        let candidates = group.locations.map {
            PathCandidate(title: $0.title, detail: $0.detail, url: context.home.appending(path: $0.path),
                          preselected: $0.preselected, hint: $0.hint)
        }
        let items = await Sizing.items(prefix: group.id, from: candidates, minimumSize: group.minimumSize)
        guard !items.isEmpty else { return nil }
        return Finding(
            id: group.id,
            area: group.area,
            tier: group.tier,
            title: group.title,
            summary: group.summary(of: items),
            explanation: group.explanation,
            method: group.method,
            actionTarget: group.actionTarget,
            items: items,
            waitsFor: group.waitsFor
        )
    }
}
