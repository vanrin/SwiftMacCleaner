//
//  StackDetector.swift
//  Mac Disk Cleaner
//
//  Works out which developer tools this Mac actually has, so the scan and the sidebar can leave
//  out the areas that have nothing to do with how its owner works. Detection only decides what
//  is looked at; what may be removed is still the reviewed list in the catalog.
//

import Foundation

/// One thing whose presence says a developer area is worth scanning.
nonisolated struct StackSign: Sendable {
    var name: String
    var area: Area
    /// Folders relative to home. A trailing `*` matches any name that starts that way.
    var paths: [String]
    /// Command-line tools, looked for in the usual install locations.
    var tools: [String]

    init(_ name: String, _ area: Area, paths: [String] = [], tools: [String] = []) {
        self.name = name
        self.area = area
        self.paths = paths
        self.tools = tools
    }
}

/// A kind of project, told by the files that sit beside its source.
nonisolated struct ProjectKind: Sendable, Hashable {
    var name: String
    var markers: Set<String>
    /// Endings that mark it too, such as `.xcodeproj`.
    var suffixes: [String]
    /// The area this kind of project fills with caches, wherever its tools keep them.
    var area: Area?

    init(_ name: String, markers: Set<String> = [], suffixes: [String] = [], area: Area? = nil) {
        self.name = name
        self.markers = markers
        self.suffixes = suffixes
        self.area = area
    }

    /// Whether a folder with these entries is a project of this kind.
    func marks(_ names: Set<String>) -> Bool {
        !names.isDisjoint(with: markers) || names.contains { name in suffixes.contains { name.hasSuffix($0) } }
    }
}

/// The tools and kinds of project found on this Mac.
nonisolated struct DetectedStack: Sendable, Equatable {
    /// What was found for each developer area, by name. An area that is missing has nothing to scan.
    var found: [Area: [String]] = [:]

    /// Whether a scan of the area could find anything. Areas every Mac has always apply.
    func applies(_ area: Area) -> Bool { !area.isDeveloper || found[area] != nil }

    /// Whether a scan looks at the area: one that applies unless it was switched off, any other only when asked for.
    func scans(_ area: Area, disabled: Set<Area>, forced: Set<Area>) -> Bool {
        applies(area) ? !disabled.contains(area) : forced.contains(area)
    }

    /// "npm, pnpm, Homebrew and 3 more": what was found for the area, for the line under its name.
    func summary(of area: Area) -> String? {
        guard let names = found[area], !names.isEmpty else { return nil }
        return names.prefix(5).joined(separator: ", ") + (names.count > 5 ? " and \(names.count - 5) more" : "")
    }

    mutating func add(_ name: String, to area: Area) {
        guard found[area]?.contains(name) != true else { return }
        found[area, default: []].append(name)
    }

    /// The same stack with what the project folders hold. A kind of project also switches on the area
    /// its tools fill, for the Mac where those tools keep their folders somewhere unusual.
    /// Projects itself applies to anyone with project folders or any other developer tool.
    func adding(_ kinds: [ProjectKind], hasProjectFolders: Bool) -> DetectedStack {
        var stack = self
        for kind in kinds {
            stack.add(kind.name, to: .projects)
            if let area = kind.area, found[area] == nil { stack.add("\(kind.name) projects", to: area) }
        }
        if stack.found[.projects] == nil, hasProjectFolders || !stack.found.isEmpty { stack.found[.projects] = [] }
        return stack
    }
}

nonisolated enum StackDetector {
    /// Every sign, in the order the names are shown. Each folder the catalog may offer sits under
    /// one of these, which a test checks, so a new catalog line cannot be left undetected.
    static let signs: [StackSign] = [
        StackSign("Xcode", .xcode, paths: [
            "Library/Developer/Xcode", "Library/Developer/CoreSimulator", "Library/Developer/XCTestDevices",
            "Library/Caches/com.apple.dt.Xcode",
        ]),

        StackSign("Gradle", .android, paths: [".gradle"], tools: ["gradle"]),
        StackSign("Android SDK", .android, paths: [".android", "Library/Android/sdk"]),

        StackSign("Docker", .containers, tools: ["docker"]),
        StackSign("OrbStack", .containers, paths: [".orbstack"]),
        StackSign("Colima", .containers, paths: [".colima"], tools: ["colima"]),
        StackSign("Lima", .containers, paths: [".lima"], tools: ["limactl"]),
        StackSign("minikube", .containers, paths: [".minikube"]),

        StackSign("npm", .packageCaches, paths: [".npm", ".cache/node/corepack", "Library/Caches/node-gyp"], tools: ["npm"]),
        StackSign("pnpm", .packageCaches, paths: ["Library/pnpm", "Library/Caches/pnpm"], tools: ["pnpm"]),
        StackSign("Yarn", .packageCaches, paths: ["Library/Caches/Yarn", ".yarn"], tools: ["yarn"]),
        StackSign("Bun", .packageCaches, paths: [".bun"], tools: ["bun"]),
        StackSign("Deno", .packageCaches, paths: ["Library/Caches/deno"], tools: ["deno"]),
        StackSign("CocoaPods", .packageCaches, paths: ["Library/Caches/CocoaPods", ".cocoapods"], tools: ["pod"]),
        StackSign("Swift packages", .packageCaches, paths: ["Library/Caches/org.swift.swiftpm"]),
        StackSign("Carthage", .packageCaches, paths: ["Library/Caches/org.carthage.CarthageKit"]),
        StackSign("Dart and Flutter", .packageCaches, paths: [".pub-cache"], tools: ["flutter", "dart"]),
        StackSign("Homebrew", .packageCaches, paths: ["Library/Caches/Homebrew"], tools: ["brew"]),
        StackSign("pip", .packageCaches, paths: ["Library/Caches/pip", ".cache/pip"]),
        StackSign("uv", .packageCaches, paths: [".cache/uv"], tools: ["uv"]),
        StackSign("Poetry", .packageCaches, paths: ["Library/Caches/pypoetry", ".cache/pypoetry"], tools: ["poetry"]),
        StackSign("conda", .packageCaches, paths: [".conda", "miniconda3", "anaconda3"], tools: ["conda"]),
        StackSign("Cargo", .packageCaches, paths: [".cargo"], tools: ["cargo"]),
        StackSign("Go", .packageCaches, paths: ["go", "Library/Caches/go-build"], tools: ["go"]),
        StackSign("Maven", .packageCaches, paths: [".m2"], tools: ["mvn"]),
        StackSign("Composer", .packageCaches, paths: [".composer", "Library/Caches/composer"], tools: ["composer"]),
        StackSign("RubyGems", .packageCaches, paths: [".gem", ".bundle"]),
        StackSign("NuGet", .packageCaches, paths: [".nuget"], tools: ["dotnet"]),
        StackSign("Playwright", .packageCaches, paths: ["Library/Caches/ms-playwright"]),
        StackSign("Cypress", .packageCaches, paths: ["Library/Caches/Cypress"]),
        StackSign("Puppeteer", .packageCaches, paths: [".cache/puppeteer"]),
        StackSign("Electron", .packageCaches, paths: ["Library/Caches/electron"]),
        StackSign("Turborepo", .packageCaches, paths: ["Library/Caches/turbo"]),

        StackSign("SDKMAN", .toolchains, paths: [".sdkman/candidates"]),
        StackSign("nvm", .toolchains, paths: [".nvm/versions"]),
        StackSign("fnm", .toolchains, paths: ["Library/Application Support/fnm"]),
        StackSign("Volta", .toolchains, paths: [".volta"]),
        StackSign("FVM", .toolchains, paths: ["fvm/versions"]),
        StackSign("pyenv", .toolchains, paths: [".pyenv/versions"]),
        StackSign("rbenv", .toolchains, paths: [".rbenv/versions"]),
        StackSign("rustup", .toolchains, paths: [".rustup/toolchains"]),
        StackSign("asdf", .toolchains, paths: [".asdf/installs"]),
        StackSign("mise", .toolchains, paths: [".local/share/mise/installs"]),

        StackSign("VS Code", .ides, paths: ["Library/Application Support/Code"]),
        StackSign("Cursor", .ides, paths: ["Library/Application Support/Cursor"]),
        StackSign("Windsurf", .ides, paths: ["Library/Application Support/Windsurf"]),
        StackSign("JetBrains", .ides, paths: [
            "Library/Caches/JetBrains", "Library/Logs/JetBrains", "Library/Application Support/JetBrains",
        ]),
        StackSign("Android Studio", .ides, paths: [
            "Library/Caches/Google/AndroidStudio*", "Library/Logs/Google/AndroidStudio*",
            "Library/Application Support/Google/AndroidStudio*",
        ]),

        StackSign("Hugging Face", .models, paths: [".cache/huggingface"]),
        StackSign("Ollama", .models, paths: [".ollama"], tools: ["ollama"]),
        StackSign("LM Studio", .models, paths: [".lmstudio", ".cache/lm-studio"]),
        StackSign("PyTorch", .models, paths: [".cache/torch"]),
        StackSign("Whisper", .models, paths: [".cache/whisper"]),
        StackSign("Keras", .models, paths: [".keras"]),
    ]

    /// The kinds of project told apart, by the same files the project scan treats as project files.
    static let projectKinds: [ProjectKind] = [
        ProjectKind("Xcode", suffixes: [".xcodeproj", ".xcworkspace"]),
        ProjectKind("Swift", markers: ["Package.swift"], area: .packageCaches),
        ProjectKind("Node", markers: ["package.json"], area: .packageCaches),
        ProjectKind("Flutter", markers: ["pubspec.yaml"], area: .packageCaches),
        ProjectKind("CocoaPods", markers: ["Podfile"], area: .packageCaches),
        ProjectKind("Gradle", markers: ["build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts"], area: .android),
        ProjectKind("Maven", markers: ["pom.xml"], area: .packageCaches),
        ProjectKind("Rust", markers: ["Cargo.toml"], area: .packageCaches),
        ProjectKind("Go", markers: ["go.mod"], area: .packageCaches),
        ProjectKind("Python", markers: ["pyproject.toml", "requirements.txt"], area: .packageCaches),
        ProjectKind("Ruby", markers: ["Gemfile"], area: .packageCaches),
    ]

    /// Folders macOS asks about before an app may read them. Looking there waits for a scan the user started.
    static let promptingFolders = ["Documents", "Desktop", "Downloads", "Library/Mobile Documents", "Library/CloudStorage"]
    /// Folders full of other people's projects, which say nothing about this one.
    static let dependencyFolders: Set<String> = ["node_modules", "Pods"]

    /// What the home folder and the tools on the PATH say. A few dozen file checks and nothing slower,
    /// so it is cheap enough to run whenever the answer is about to be shown or used.
    static func detect(home: URL, searchDirectories: [String] = Shell.searchDirectories) -> DetectedStack {
        var stack = DetectedStack()
        for sign in signs where isPresent(sign, home: home, searchDirectories: searchDirectories) {
            stack.add(sign.name, to: sign.area)
        }
        return stack
    }

    private static func isPresent(_ sign: StackSign, home: URL, searchDirectories: [String]) -> Bool {
        if sign.paths.contains(where: { exists($0, home: home) }) { return true }
        return sign.tools.contains { tool in
            searchDirectories.contains { FileManager.default.isExecutableFile(atPath: "\($0)/\(tool)") }
        }
    }

    private static func exists(_ path: String, home: URL) -> Bool {
        guard path.hasSuffix("*") else { return Files.exists(home.appending(path: path)) }
        let pattern = home.appending(path: String(path.dropLast()))
        let prefix = pattern.lastPathComponent
        return Files.children(of: pattern.deletingLastPathComponent()).contains { $0.lastPathComponent.hasPrefix(prefix) }
    }

    /// The kinds of project in the project folders. Reads the folders nearest the top first, two
    /// levels down at most, and stops after `limit` of them: enough to know a stack without walking it.
    @concurrent
    static func projectKinds(in roots: [URL], home: URL, limit: Int = 300) async -> [ProjectKind] {
        var found = Set<ProjectKind>()
        var pending = roots.filter { !raisesPrompt($0, home: home) }.map { (folder: $0, depth: 0) }
        var next = 0
        while next < pending.count, next < limit, found.count < projectKinds.count, !Task.isCancelled {
            let (folder, depth) = pending[next]
            next += 1
            let entries = Files.children(of: folder)
            let names = Set(entries.map(\.lastPathComponent))
            found.formUnion(projectKinds.filter { $0.marks(names) })
            guard depth < 2 else { continue }
            pending += entries
                .filter { entry in
                    let name = entry.lastPathComponent
                    return !name.hasPrefix(".") && !dependencyFolders.contains(name) && Files.isDirectory(entry) && !Files.isSymlink(entry)
                }
                .map { (folder: $0, depth: depth + 1) }
        }
        return projectKinds.filter(found.contains)
    }

    static func raisesPrompt(_ url: URL, home: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return promptingFolders.contains { folder in
            let prompting = home.appending(path: folder).path
            return path == prompting || path.hasPrefix(prompting + "/")
        }
    }
}
