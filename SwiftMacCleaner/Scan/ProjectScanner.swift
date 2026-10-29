//
//  ProjectScanner.swift
//  SwiftMacCleaner
//

import Foundation

/// Finds dependency and build folders inside projects nobody has touched for a while.
nonisolated enum ProjectScanner {
    struct Project {
        var root: URL
        var generated: [URL] = []
        var lastTouched = Date.distantPast
        var restore: [String] = []
    }

    static let markerFiles: Set<String> = [
        "package.json", "pubspec.yaml", "Podfile", "build.gradle", "build.gradle.kts", "settings.gradle",
        "settings.gradle.kts", "Cargo.toml", "pom.xml", "Package.swift", "pyproject.toml", "requirements.txt",
        "go.mod", "Gemfile",
    ]
    static let gradleFiles: Set<String> = [
        "build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts", "gradlew",
    ]
    static let webCacheFolders: Set<String> = [".next", ".nuxt", ".turbo", ".parcel-cache", ".angular", ".svelte-kit"]
    static let skippedFolders: Set<String> = ["Library", "Applications", "Pictures", "Music", "Movies"]
    static let maxDepth = 8

    static func scan(_ context: ScanContext) async -> AreaScanResult {
        let roots = context.projectRoots.filter(Files.isDirectory)
        guard !roots.isEmpty else {
            return AreaScanResult(skipReason: "No project folders to look in. Add one in Settings.")
        }
        var result = AreaScanResult()
        var projects: [URL: Project] = [:]
        var cloudRoots: [URL] = []
        for root in roots {
            if isInCloud(root, context: context) {
                cloudRoots.append(root)
                continue
            }
            walk(root, depth: 0, owner: nil, projects: &projects, cloud: &cloudRoots, context: context)
        }
        for root in cloudRoots {
            result.protected.append(ProtectedItem(
                id: "projects.cloud/\(root.path)",
                area: .projects,
                title: root.lastPathComponent,
                why: "Project folders in iCloud are left alone: deleting there deletes everywhere",
                rule: .protectedList,
                size: nil
            ))
        }

        let withOutput = projects.values.filter { !$0.generated.isEmpty }
        let stale = withOutput.filter { $0.lastTouched < context.staleCutoff }
        let active = withOutput.filter { $0.lastTouched >= context.staleCutoff }.sorted { $0.lastTouched > $1.lastTouched }
        for project in active {
            result.protected.append(ProtectedItem(
                id: "projects.active/\(project.root.path)",
                area: .projects,
                title: project.root.lastPathComponent,
                why: "\(context.tilde(project.root)), touched \(context.relative(project.lastTouched))",
                rule: .recentlyUsed,
                size: nil
            ))
        }
        if let finding = await flutterBuildCaches(in: active, context: context) { result.findings.append(finding) }
        guard !stale.isEmpty else {
            result.skipReason = (active.isEmpty && cloudRoots.isEmpty) || !result.findings.isEmpty
                ? nil
                : "Every project with build output was touched in the last \(context.staleDays) days."
            return result
        }

        let sizes = await Sizing.sizes(of: stale.flatMap(\.generated))
        var items: [FindingItem] = []
        for project in stale {
            let size = project.generated.reduce(Int64(0)) { $0 + (sizes[$1] ?? 0) }
            guard size >= 1_000_000 else { continue }
            let names = project.generated.map { relativePath(of: $0, in: project.root) }.sorted()
            let shown = names.prefix(3).joined(separator: ", ") + (names.count > 3 ? " and \(names.count - 3) more" : "")
            let touched = project.lastTouched == .distantPast
                ? "no source files left"
                : "last touched \(context.relative(project.lastTouched))"
            items.append(FindingItem(
                id: "projects.stale/\(project.root.path)",
                title: project.root.lastPathComponent,
                detail: "\(context.tilde(project.root)) · \(shown) · \(touched)",
                size: size,
                paths: project.generated,
                hint: project.restore.isEmpty ? nil : project.restore.joined(separator: ", then ")
            ))
        }
        guard !items.isEmpty else { return result }
        items.sort { $0.size > $1.size }

        var note: String?
        if !active.isEmpty {
            let projects = active.count == 1 ? "1 project" : "\(active.count) projects"
            note = "Left out on purpose: \(projects) touched in the last \(context.staleDays) days."
        }
        result.findings.append(Finding(
            id: "projects.stale",
            area: .projects,
            aftermath: .rebuilds,
            title: "Stale project dependencies",
            summary: "node_modules, Pods and build folders in \(items.count) \(items.count == 1 ? "project" : "projects") untouched for \(context.staleDays)+ days",
            explanation: "Dependency and build folders inside projects you have stopped touching. Source files are never touched, and each project comes back with the command shown in its row.",
            method: .delete,
            actionTarget: "Generated folders only, in " + roots.map(context.tilde).joined(separator: ", "),
            items: items,
            note: note
        ))
        return result
    }

    // MARK: Old Flutter build caches

    static let buildCachesFindingID = "projects.buildCaches"

    /// Flutter keeps a build cache in `.dart_tool/flutter_build` for every mix of target, mode, defines
    /// and Flutter version it has built, and a compiled kernel file for each in `build`, and never removes
    /// the old ones. In a project still in use, the ones untouched for a week are offered, and the newest
    /// of each kind always stays, since it is most likely the build in use. Stale projects are left to
    /// the stale finding, which offers the whole folders.
    static func flutterBuildCaches(in projects: [Project], context: ScanContext,
                                   minimumSize: Int64 = 20_000_000) async -> Finding? {
        var groups: [PathGroup] = []
        for project in projects {
            var old: [URL] = []
            for dartTool in project.generated where dartTool.lastPathComponent == ".dart_tool" {
                old += idleEntries(Files.subdirectories(of: dartTool.appending(path: "flutter_build")), context: context)
                let build = dartTool.deletingLastPathComponent().appending(path: "build")
                let kernels = Files.children(of: build).filter { $0.lastPathComponent.hasSuffix(".cache.dill.track.dill") }
                old += idleEntries(kernels, context: context)
            }
            guard !old.isEmpty else { continue }
            groups.append(PathGroup(
                id: project.root.path,
                title: project.root.lastPathComponent,
                detail: "\(context.tilde(project.root)) · \(old.count) old build \(old.count == 1 ? "cache" : "caches"), untouched for \(context.recentBuildDays)+ days",
                paths: old,
                hint: "flutter clean also clears them"
            ))
        }
        let items = await Sizing.items(prefix: buildCachesFindingID, from: groups, minimumSize: minimumSize)
        guard !items.isEmpty else { return nil }
        return Finding(
            id: buildCachesFindingID,
            area: .projects,
            aftermath: .rebuilds,
            title: "Old Flutter build caches",
            summary: "In \(items.count) \(items.count == 1 ? "project" : "projects") you are still working on",
            explanation: "Flutter keeps a build cache for every combination of target, mode and Flutter version it has built, and never removes the old ones. Only caches untouched for a week are offered, and the newest one in each project always stays. A build that needs one again makes it again.",
            method: .delete,
            actionTarget: ".dart_tool/flutter_build and build/*.dill in each project",
            items: items
        )
    }

    /// The entries nothing has written to since the recent-build cutoff, less the newest one.
    static func idleEntries(_ entries: [URL], context: ScanContext) -> [URL] {
        let dated = entries.compactMap { url in Cleaner.newestChange(in: url).map { (url: url, date: $0) } }
        guard let newest = dated.max(by: { $0.date < $1.date }) else { return [] }
        return dated.filter { $0.url != newest.url && $0.date < context.recentBuildCutoff }.map(\.url)
    }

    /// Whether a folder lives in iCloud, where a local delete becomes a delete everywhere.
    static func isInCloud(_ url: URL, context: ScanContext) -> Bool {
        let path = url.standardizedFileURL.path
        let home = context.home.path
        for cloud in ["Library/Mobile Documents", "Library/CloudStorage"] where path.hasPrefix("\(home)/\(cloud)") {
            return true
        }
        return (try? url.resourceValues(forKeys: [.isUbiquitousItemKey]))?.isUbiquitousItem == true
    }

    /// Walks a folder tree, grouping generated folders under the project that owns them.
    ///
    /// A project starts at a Git repository, or failing that at the first folder holding a
    /// project file. Everything below belongs to it until a nested repository begins.
    /// A project folder kept in iCloud is noted in `cloud` and never entered.
    static func walk(_ directory: URL, depth: Int, owner: URL?, projects: inout [URL: Project],
                     cloud: inout [URL], context: ScanContext) {
        guard depth <= maxDepth, !Task.isCancelled else { return }
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey]
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: Array(keys), options: []
        ) else { return }

        let names = Set(entries.map(\.lastPathComponent))
        let hasMarker = !names.isDisjoint(with: markerFiles)
            || names.contains { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }
        let generatedNames = Set(names.filter { isGenerated($0, in: directory, siblings: names) })

        var owner = owner
        if names.contains(".git") || (owner == nil && (hasMarker || !generatedNames.isEmpty)) {
            if owner == nil || names.contains(".git"), isInCloud(directory, context: context) {
                cloud.append(directory)
                return
            }
            owner = directory
        }
        if let owner, projects[owner] == nil {
            projects[owner] = Project(root: owner)
        }

        for entry in entries {
            let name = entry.lastPathComponent
            let values = try? entry.resourceValues(forKeys: keys)
            if values?.isSymbolicLink == true { continue }
            let modified = values?.contentModificationDate

            guard values?.isDirectory == true else {
                if let owner, name != ".DS_Store" { touch(owner, modified, in: &projects) }
                continue
            }
            if generatedNames.contains(name) {
                guard let owner else { continue }
                projects[owner]?.generated.append(entry)
                // A build folder rewritten last week means the project is still in use.
                touch(owner, modified, in: &projects)
                if let command = restoreCommand(for: name, siblings: names),
                   projects[owner]?.restore.contains(command) == false {
                    projects[owner]?.restore.append(command)
                }
                continue
            }
            if name == ".git" {
                for file in ["HEAD", "index"] {
                    if let owner { touch(owner, Files.modificationDate(entry.appending(path: file)), in: &projects) }
                }
                continue
            }
            if name.hasPrefix(".") || skippedFolders.contains(name) { continue }
            walk(entry, depth: depth + 1, owner: owner, projects: &projects, cloud: &cloud, context: context)
        }
    }

    private static func touch(_ owner: URL, _ date: Date?, in projects: inout [URL: Project]) {
        guard let date, let current = projects[owner]?.lastTouched, date > current else { return }
        projects[owner]?.lastTouched = date
    }

    /// Whether a folder name is build output or dependencies, judged by the project files beside it.
    static func isGenerated(_ name: String, in directory: URL, siblings: Set<String>) -> Bool {
        switch name {
        case "node_modules":
            return true
        case "Pods":
            return siblings.contains("Podfile")
        case ".dart_tool":
            return siblings.contains("pubspec.yaml")
        case "build":
            return siblings.contains("pubspec.yaml") || siblings.contains("build.gradle") || siblings.contains("build.gradle.kts")
        case ".gradle":
            return !siblings.isDisjoint(with: gradleFiles)
        case "target":
            return siblings.contains("Cargo.toml") || siblings.contains("pom.xml")
        case ".venv", "venv":
            return Files.exists(directory.appending(path: name).appending(path: "pyvenv.cfg"))
        case ".build":
            return siblings.contains("Package.swift")
        case "DerivedData":
            return siblings.contains("Package.swift")
                || siblings.contains { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }
        default:
            return webCacheFolders.contains(name) && siblings.contains("package.json")
        }
    }

    static func restoreCommand(for name: String, siblings: Set<String>) -> String? {
        switch name {
        case "node_modules":
            if siblings.contains("pnpm-lock.yaml") { return "pnpm install" }
            if siblings.contains("yarn.lock") { return "yarn install" }
            if siblings.contains("bun.lockb") || siblings.contains("bun.lock") { return "bun install" }
            return "npm install"
        case "Pods": return "pod install"
        case ".dart_tool": return "flutter pub get"
        case "build": return siblings.contains("pubspec.yaml") ? "flutter pub get" : "./gradlew build"
        case ".gradle": return "./gradlew build"
        case "target": return siblings.contains("Cargo.toml") ? "cargo build" : "mvn install"
        case ".venv", "venv": return "recreate the virtual environment"
        case ".build": return "swift build"
        default: return nil
        }
    }

    private static func relativePath(of url: URL, in root: URL) -> String {
        let path = url.path
        let rootPath = root.path
        return path.hasPrefix(rootPath + "/") ? String(path.dropFirst(rootPath.count + 1)) : url.lastPathComponent
    }
}
