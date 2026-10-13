//
//  Catalog.swift
//  SwiftMacCleaner
//
//  One reviewed list of every fixed location the app may offer. Scanners that only need
//  "measure these folders and offer the big ones" read their entries from here, so a new
//  cache is one line, and a test can walk the whole list past the safety guard.
//
//  A tool that can be told to keep its folder somewhere else is also asked where that is.
//  What it answers is offered separately and more carefully than the reviewed folders.
//

import Foundation

/// A way to ask where a folder really is, for a tool that can be told to keep it somewhere else.
nonisolated enum Locator: Sendable {
    /// An environment variable that names the folder, or a parent that `subpath` is added to.
    case variable(String, subpath: String = "")
    /// A command that prints the folder, or a parent that `subpath` is added to.
    case command(String, [String], subpath: String = "")

    /// What was asked, as the row shows it: "CARGO_HOME" or "npm config get cache".
    var source: String {
        switch self {
        case .variable(let name, _): name
        case .command(let tool, let arguments, _): ([tool] + arguments).joined(separator: " ")
        }
    }

    var subpath: String {
        switch self {
        case .variable(_, let subpath), .command(_, _, let subpath): subpath
        }
    }
}

/// A folder with a fixed place in the home folder.
nonisolated struct KnownLocation: Sendable {
    var title: String
    var detail: String
    /// Relative to home.
    var path: String
    var preselected: Bool? = nil
    var hint: String? = nil
    /// How to find the folder when it is not at `path`, most trusted first. The first one that answers wins.
    var asks: [Locator] = []

    init(_ title: String, _ path: String, _ detail: String, preselected: Bool? = nil, hint: String? = nil,
         asks: [Locator] = []) {
        self.title = title
        self.path = path
        self.detail = detail
        self.preselected = preselected
        self.hint = hint ?? "~/" + path
        self.asks = asks
    }
}

/// A catalog folder found somewhere other than its usual place, and what said so.
nonisolated struct MovedLocation: Sendable {
    var location: KnownLocation
    var url: URL
    var source: String
}

/// A finding made entirely of known locations.
nonisolated struct LocationGroup: Sendable {
    var id: String
    var area: Area
    var aftermath: Aftermath
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
        id: "packages.caches", area: .packageCaches, aftermath: .rebuilds, method: .delete,
        title: "Package manager caches",
        explanation: "Copies of packages your package managers have already downloaded. Anything a project needs is fetched again the next time you install.",
        actionTarget: "Each package manager's cache folder",
        locations: [
            KnownLocation("npm cache", ".npm/_cacache", "Packages npm has downloaded",
                          asks: npm("_cacache")),
            KnownLocation("npx cache", ".npm/_npx", "Packages npx fetched to run once",
                          asks: npm("_npx")),
            KnownLocation("npm logs", ".npm/_logs", "Logs from past npm runs",
                          asks: npm("_logs")),
            KnownLocation("pnpm store", "Library/pnpm/store", "Packages pnpm has downloaded. Installed projects keep working",
                          asks: [.command("pnpm", ["store", "path"])]),
            KnownLocation("pnpm cache", "Library/Caches/pnpm", "Metadata pnpm has fetched"),
            KnownLocation("Yarn cache", "Library/Caches/Yarn", "Packages Yarn has downloaded",
                          asks: [.command("yarn", ["cache", "dir"]), .variable("YARN_CACHE_FOLDER")]),
            KnownLocation("Yarn Berry cache", ".yarn/berry/cache", "Packages Yarn has downloaded"),
            KnownLocation("Bun cache", ".bun/install/cache", "Packages Bun has downloaded",
                          asks: [.variable("BUN_INSTALL_CACHE_DIR"), .variable("BUN_INSTALL", subpath: "install/cache")]),
            KnownLocation("Corepack cache", ".cache/node/corepack", "Package manager builds Corepack has downloaded",
                          asks: [.variable("COREPACK_HOME")]),
            KnownLocation("Deno cache", "Library/Caches/deno", "Modules Deno has downloaded",
                          asks: [.variable("DENO_DIR")]),
            KnownLocation("CocoaPods cache", "Library/Caches/CocoaPods", "Pods downloaded for past installs",
                          asks: [.variable("CP_CACHE_DIR")]),
            KnownLocation("CocoaPods master specs", ".cocoapods/repos/master",
                          "The old full clone of the specs repo. CocoaPods now uses the much smaller trunk CDN instead",
                          preselected: false,
                          asks: [.variable("CP_REPOS_DIR", subpath: "master"), .variable("CP_HOME_DIR", subpath: "repos/master")]),
            KnownLocation("Dart and Flutter packages", ".pub-cache/hosted", "Packages from pub.dev, fetched again by flutter pub get",
                          asks: [.variable("PUB_CACHE", subpath: "hosted")]),
            KnownLocation("Dart packages from Git", ".pub-cache/git", "Git dependencies, cloned again by flutter pub get",
                          asks: [.variable("PUB_CACHE", subpath: "git")]),
            KnownLocation("Homebrew downloads", "Library/Caches/Homebrew", "Installers for formulae and casks you already installed",
                          asks: [.command("brew", ["--cache"]), .variable("HOMEBREW_CACHE")]),
            KnownLocation("pip cache", "Library/Caches/pip", "Wheels pip has downloaded or built",
                          asks: [.command("pip3", ["cache", "dir"]), .variable("PIP_CACHE_DIR")]),
            KnownLocation("pip cache", ".cache/pip", "Wheels pip has downloaded or built"),
            KnownLocation("uv cache", ".cache/uv", "Packages uv has downloaded or built",
                          asks: [.command("uv", ["cache", "dir"]), .variable("UV_CACHE_DIR")]),
            KnownLocation("Poetry cache", "Library/Caches/pypoetry", "Packages Poetry has downloaded",
                          asks: [.variable("POETRY_CACHE_DIR")]),
            KnownLocation("Poetry cache", ".cache/pypoetry", "Packages Poetry has downloaded"),
            KnownLocation("conda packages", ".conda/pkgs", "Packages conda has downloaded. Environments keep their own copies"),
            KnownLocation("Miniconda packages", "miniconda3/pkgs", "Packages conda has downloaded. Environments keep their own copies"),
            KnownLocation("Anaconda packages", "anaconda3/pkgs", "Packages conda has downloaded. Environments keep their own copies"),
            KnownLocation("Swift Package Manager cache", "Library/Caches/org.swift.swiftpm", "Package checkouts, cloned again when resolved"),
            KnownLocation("Carthage cache", "Library/Caches/org.carthage.CarthageKit", "Dependencies Carthage has built"),
            KnownLocation("Cargo registry", ".cargo/registry", "Crates downloaded from crates.io",
                          asks: [.variable("CARGO_HOME", subpath: "registry")]),
            KnownLocation("Cargo Git checkouts", ".cargo/git", "Git dependencies, cloned again by cargo build",
                          asks: [.variable("CARGO_HOME", subpath: "git")]),
            KnownLocation("Go build cache", "Library/Caches/go-build", "Compiled packages, rebuilt on the next go build",
                          asks: [.command("go", ["env", "GOCACHE"]), .variable("GOCACHE")]),
            KnownLocation("Composer cache", ".composer/cache", "PHP packages Composer has downloaded",
                          asks: [.variable("COMPOSER_CACHE_DIR"), .variable("COMPOSER_HOME", subpath: "cache")]),
            KnownLocation("Composer cache", "Library/Caches/composer", "PHP packages Composer has downloaded"),
            KnownLocation("RubyGems specs", ".gem/specs", "Gem index files, fetched again by gem and bundle"),
            KnownLocation("Bundler cache", ".bundle/cache", "Gems Bundler has downloaded"),
            KnownLocation("NuGet packages", ".nuget/packages",
                          "Packages NuGet has downloaded. Restored again on the next dotnet restore", preselected: false,
                          asks: [.variable("NUGET_PACKAGES")]),
            KnownLocation("Playwright browsers", "Library/Caches/ms-playwright", "Browsers downloaded for tests",
                          asks: [.variable("PLAYWRIGHT_BROWSERS_PATH")]),
            KnownLocation("Cypress binaries", "Library/Caches/Cypress", "Cypress versions downloaded for tests",
                          asks: [.variable("CYPRESS_CACHE_FOLDER")]),
            KnownLocation("Puppeteer browsers", ".cache/puppeteer", "Browsers downloaded for automation",
                          asks: [.variable("PUPPETEER_CACHE_DIR")]),
            KnownLocation("Electron downloads", "Library/Caches/electron", "Electron builds downloaded by npm",
                          asks: [.variable("ELECTRON_CACHE")]),
            KnownLocation("node-gyp headers", "Library/Caches/node-gyp", "Node headers for building native modules"),
            KnownLocation("Turborepo cache", "Library/Caches/turbo", "Remote cache artefacts Turborepo has fetched"),
            KnownLocation("Maven repository", ".m2/repository",
                          "Downloaded again by Maven, except anything you installed locally with mvn install",
                          preselected: false),
        ]
    )

    /// npm keeps its cache, its npx packages and its logs in one folder, which `.npmrc` can move.
    private static func npm(_ subpath: String) -> [Locator] {
        [.command("npm", ["config", "get", "cache"], subpath: subpath), .variable("npm_config_cache", subpath: subpath)]
    }

    static let goModules = LocationGroup(
        id: "packages.goModules", area: .packageCaches, aftermath: .downloadsAgain, method: .trash,
        title: "Go module cache",
        explanation: "Every Go module you have ever built against. The next go build downloads what the project needs again, which can take a while on a slow connection.",
        actionTarget: "~/go/pkg/mod",
        minimumSize: 50_000_000,
        locations: [
            KnownLocation("Go modules", "go/pkg/mod", "Downloaded again on the next go build or go mod download",
                          asks: [.command("go", ["env", "GOMODCACHE"]), .variable("GOMODCACHE")]),
        ]
    )

    static let gradle = LocationGroup(
        id: "android.gradle", area: .android, aftermath: .rebuilds, method: .delete,
        title: "Gradle caches",
        explanation: "Dependencies and build output Gradle has downloaded or produced. The next Gradle sync fetches what it needs again, which makes that first build slower.",
        actionTarget: "~/.gradle/caches, ~/.gradle/wrapper/dists",
        minimumSize: 1_000_000,
        waitsFor: .gradleDaemon,
        locations: [
            KnownLocation("Gradle dependencies and build cache", ".gradle/caches", "Downloaded again on the next Gradle sync",
                          asks: [.variable("GRADLE_USER_HOME", subpath: "caches")]),
            KnownLocation("Gradle wrapper distributions", ".gradle/wrapper/dists", "Each Gradle version is downloaded again when a project asks for it",
                          asks: [.variable("GRADLE_USER_HOME", subpath: "wrapper/dists")]),
            KnownLocation("Gradle daemon logs", ".gradle/daemon", "Logs left by past Gradle daemons",
                          asks: [.variable("GRADLE_USER_HOME", subpath: "daemon")]),
            KnownLocation("Android build cache", ".android/build-cache", "Build output shared between Android projects",
                          asks: [.variable("ANDROID_USER_HOME", subpath: "build-cache")]),
            KnownLocation("Android SDK cache", ".android/cache", "Downloads kept by the SDK tools",
                          asks: [.variable("ANDROID_USER_HOME", subpath: "cache")]),
        ]
    )

    static let xcodeCaches = LocationGroup(
        id: "xcode.caches", area: .xcode, aftermath: .rebuilds, method: .delete,
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
        id: "xcode.leftovers", area: .xcode, aftermath: .rebuilds, method: .delete,
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
        id: "models.downloads", area: .models, aftermath: .downloadsAgain, method: .trash,
        title: "Model and dataset downloads",
        explanation: "Models and datasets your tools fetched from a hub. Each one is downloaded again on first use, and some are tens of gigabytes. Nothing here is ticked for you.",
        actionTarget: "~/.cache/huggingface, ~/.cache/torch, ~/.lmstudio and friends",
        minimumSize: 100_000_000,
        locations: [
            KnownLocation("Hugging Face hub cache", ".cache/huggingface/hub", "Models and datasets from huggingface.co", preselected: false,
                          asks: [.variable("HF_HUB_CACHE"), .variable("HF_HOME", subpath: "hub")]),
            KnownLocation("Hugging Face datasets", ".cache/huggingface/datasets", "Processed datasets", preselected: false,
                          asks: [.variable("HF_DATASETS_CACHE"), .variable("HF_HOME", subpath: "datasets")]),
            KnownLocation("PyTorch hub", ".cache/torch", "Models and weights from torch.hub", preselected: false,
                          asks: [.variable("TORCH_HOME")]),
            KnownLocation("LM Studio models", ".lmstudio/models", "Models downloaded in LM Studio", preselected: false),
            KnownLocation("LM Studio models", ".cache/lm-studio/models", "Models downloaded in LM Studio", preselected: false),
            KnownLocation("Whisper models", ".cache/whisper", "Speech models downloaded by Whisper", preselected: false),
            KnownLocation("Keras models", ".keras/models", "Models Keras has downloaded", preselected: false,
                          asks: [.variable("KERAS_HOME", subpath: "models")]),
            KnownLocation("Keras datasets", ".keras/datasets", "Datasets Keras has downloaded", preselected: false,
                          asks: [.variable("KERAS_HOME", subpath: "datasets")]),
            KnownLocation("Ollama models", ".ollama/models", "Models pulled with ollama. Pull them again when you need them", preselected: false,
                          asks: [.variable("OLLAMA_MODELS")]),
        ]
    )

    static let editorCaches: [LocationGroup] = [
        LocationGroup(
            id: "ides.vscode", area: .ides, aftermath: .rebuilds, method: .delete,
            title: "VS Code caches and logs",
            explanation: "Caches, compiled extension bundles and logs VS Code rebuilds as it runs. Settings and extensions are left alone.",
            actionTarget: "~/Library/Application Support/Code",
            waitsFor: .app(bundleID: "com.microsoft.VSCode", name: "VS Code"),
            locations: Self.electronEditor("Code")
        ),
        LocationGroup(
            id: "ides.cursor", area: .ides, aftermath: .rebuilds, method: .delete,
            title: "Cursor caches and logs",
            explanation: "Caches, compiled extension bundles and logs Cursor rebuilds as it runs. Settings and extensions are left alone.",
            actionTarget: "~/Library/Application Support/Cursor",
            waitsFor: .app(bundleID: "com.todesktop.230313mzl4w4u92", name: "Cursor"),
            locations: Self.electronEditor("Cursor")
        ),
        LocationGroup(
            id: "ides.windsurf", area: .ides, aftermath: .rebuilds, method: .delete,
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
        id: "containers.caches", area: .containers, aftermath: .rebuilds, method: .delete,
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
    /// What a group turns into once its tools have been asked where they keep things.
    struct Report {
        var findings: [Finding] = []
        var protected: [ProtectedItem] = []
    }

    /// Stands in for the path of a group whose folders are not all in the usual place.
    static let eachRowTarget = "The folder shown in each row"

    /// The group's folders in their usual places only.
    static func finding(for group: LocationGroup, context: ScanContext) async -> Finding? {
        let items = await Sizing.items(prefix: group.id, from: usualCandidates(for: group, context: context),
                                       minimumSize: group.minimumSize)
        return finding(for: group, items: items)
    }

    /// The group's folders in their usual places, and the same folders wherever its tools say they keep them.
    ///
    /// A group that is deleted outright keeps to its reviewed folders. What a tool reported is offered
    /// in a finding of its own that goes to the Trash and is never ticked for the user, so the one-step
    /// clean only ever removes folders that were written down and checked in advance.
    static func report(for group: LocationGroup, context: ScanContext) async -> Report {
        let moved = await moved(in: group, context: context)
        var report = Report(protected: moved.protected)
        let elsewhere = moved.folders.map { candidate(for: $0, context: context) }
        let together = group.aftermath != .rebuilds

        let candidates = usualCandidates(for: group, context: context) + (together ? elsewhere : [])
        let items = await Sizing.items(prefix: group.id, from: candidates, minimumSize: group.minimumSize)
        let movedPaths = Set(elsewhere.map(\.url))
        if var finding = finding(for: group, items: items) {
            if items.contains(where: { $0.paths.contains(where: movedPaths.contains) }) { finding.actionTarget = eachRowTarget }
            report.findings.append(finding)
        }
        guard !together else { return report }

        let movedItems = await Sizing.items(prefix: "\(group.id).moved", from: elsewhere, minimumSize: group.minimumSize)
        guard !movedItems.isEmpty else { return report }
        report.findings.append(Finding(
            id: "\(group.id).moved",
            area: group.area,
            aftermath: .downloadsAgain,
            title: "\(group.title) in other folders",
            summary: group.summary(of: movedItems),
            explanation: "The same kind of files, in folders your tools were set up to use instead of the usual ones. The app asked each tool where it keeps them. They go to the Trash rather than being deleted, and nothing here is ticked for you.",
            method: .trash,
            actionTarget: eachRowTarget,
            items: movedItems,
            waitsFor: group.waitsFor
        ))
        return report
    }

    private static func finding(for group: LocationGroup, items: [FindingItem]) -> Finding? {
        guard !items.isEmpty else { return nil }
        return Finding(
            id: group.id,
            area: group.area,
            aftermath: group.aftermath,
            title: group.title,
            summary: group.summary(of: items),
            explanation: group.explanation,
            method: group.method,
            actionTarget: group.actionTarget,
            items: items,
            waitsFor: group.waitsFor
        )
    }

    private static func usualCandidates(for group: LocationGroup, context: ScanContext) -> [PathCandidate] {
        group.locations.map {
            PathCandidate(title: $0.title, detail: $0.detail, url: context.home.appending(path: $0.path),
                          preselected: $0.preselected, hint: $0.hint)
        }
    }

    /// A folder a tool reported, as a row: never ticked, and saying what pointed at it.
    static func candidate(for moved: MovedLocation, context: ScanContext) -> PathCandidate {
        PathCandidate(title: moved.location.title, detail: "\(moved.location.detail). Found through \(moved.source)",
                      url: moved.url, preselected: false, hint: context.tilde(moved.url))
    }

    // MARK: Asking the tools

    /// The group's folders that are somewhere other than the usual place, going by what each tool says.
    ///
    /// A folder the safety guard would refuse, such as one on another disk, is listed as left alone
    /// instead of offered. Nothing is asked when the scan carries no shell environment, as in tests.
    static func moved(in group: LocationGroup, context: ScanContext) async -> (folders: [MovedLocation], protected: [ProtectedItem]) {
        guard let environment = await context.shell?.value else { return ([], []) }
        let answers = await answers(to: group.locations.flatMap(\.asks), environment: environment, home: context.home)
        let home = context.home
        let usual = Catalog.allGroups.flatMap(\.locations).map { home.appending(path: $0.path).resolvingSymlinksInPath().path }
        // Whatever sits in ~/Library/Caches and is not a catalog folder is the general cache scan's to offer.
        let covered = usual + [home.appending(path: "Library/Caches").resolvingSymlinksInPath().path]
        let safety = SafetyGuard(root: home)

        var folders: [MovedLocation] = []
        var protected: [ProtectedItem] = []
        var seen = Set<String>()
        for location in group.locations {
            guard let (url, source) = reported(location, answers: answers, environment: environment),
                  Files.isDirectory(url) else { continue }
            let resolved = url.resolvingSymlinksInPath().path
            // Not a folder that is already offered, nor one that holds a reviewed folder inside it.
            guard !covered.contains(where: { resolved == $0 || resolved.hasPrefix($0 + "/") }),
                  !usual.contains(where: { $0.hasPrefix(resolved + "/") }),
                  seen.insert(resolved).inserted else { continue }
            if let refusal = safety.refusal(for: url) {
                let reason = refusal == "outside the allowed area" ? "outside your home folder" : refusal
                protected.append(ProtectedItem(
                    id: "\(group.id).moved/\(url.path)", area: group.area, title: location.title,
                    why: "\(source) points at \(context.tilde(url)), which is \(reason)",
                    rule: refusal == "on another disk" || refusal == "outside the allowed area" ? .otherDisk : .protectedList,
                    size: nil
                ))
                continue
            }
            folders.append(MovedLocation(location: location, url: url, source: source))
        }
        return (folders, protected)
    }

    /// Where the first of a location's questions that got an answer points, and which question it was.
    /// A folder under `~/.cache` also follows `XDG_CACHE_HOME`, as the tools that write there do.
    private static func reported(_ location: KnownLocation, answers: [String: URL],
                                 environment: ShellEnvironment) -> (url: URL, source: String)? {
        for ask in location.asks {
            let base: URL? = switch ask {
            case .variable(let name, _): environment.folder(named: name)
            case .command: answers[ask.source]
            }
            guard let base else { continue }
            return (ask.subpath.isEmpty ? base : base.appending(path: ask.subpath), ask.source)
        }
        let cache = ".cache/"
        guard location.path.hasPrefix(cache), let base = environment.folder(named: "XDG_CACHE_HOME") else { return nil }
        return (base.appending(path: String(location.path.dropFirst(cache.count))), "XDG_CACHE_HOME")
    }

    /// Runs each distinct command once, side by side, and keeps the folders they printed.
    @concurrent
    private static func answers(to asks: [Locator], environment: ShellEnvironment, home: URL) async -> [String: URL] {
        var commands: [String: (tool: String, arguments: [String])] = [:]
        for ask in asks {
            if case .command(let tool, let arguments, _) = ask { commands[ask.source] = (tool, arguments) }
        }
        return await withTaskGroup(of: (String, URL?).self) { group in
            for (source, command) in commands {
                group.addTask { (source, environment.folder(printedBy: command.tool, command.arguments, startingIn: home)) }
            }
            var answers: [String: URL] = [:]
            for await (source, url) in group { answers[source] = url }
            return answers
        }
    }
}
