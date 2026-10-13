//
//  IDEScanner.swift
//  SwiftMacCleaner
//

import Foundation

/// Editor caches, and the folders JetBrains IDEs leave behind for versions you no longer run.
nonisolated enum IDEScanner {
    /// Matches the IDE processes themselves, not the Toolbox agent that sits in the menu bar all day.
    static let jetBrainsCheck = InUseCheck.process(
        pattern: "Contents/MacOS/(idea|pycharm|webstorm|goland|clion|rider|rubymine|phpstorm|datagrip|appcode|fleet|studio)",
        name: "A JetBrains IDE", remedy: "Quit the IDE"
    )

    /// Where one product-version keeps its folders.
    struct Install {
        var product: String
        var version: String
        var caches: URL?
        var logs: URL?
        var support: URL?

        var folders: [URL] { [caches, logs, support].compactMap { $0 } }
    }

    static func scan(_ context: ScanContext) async -> AreaScanResult {
        var result = AreaScanResult()
        for group in Catalog.editorCaches {
            if let finding = await CatalogScanner.finding(for: group, context: context) {
                result.findings.append(finding)
            }
        }

        let installs = installs(home: context.home)
        let (current, old) = split(installs)

        let currentFolders = current.flatMap { install in
            [install.caches, install.logs].compactMap { $0 }.map { folder in
                PathCandidate(title: "\(friendlyName(install.product)) \(install.version) \(folder.path.contains("/Logs/") ? "logs" : "caches")",
                              detail: "Rebuilt by the IDE as it runs", url: folder)
            }
        }
        let currentItems = await Sizing.items(prefix: "ides.jetbrains", from: currentFolders, minimumSize: 10_000_000)
        if !currentItems.isEmpty {
            result.findings.append(Finding(
                id: "ides.jetbrains",
                area: .ides,
                aftermath: .rebuilds,
                title: "JetBrains caches and logs",
                summary: currentItems.prefix(3).map(\.title).joined(separator: ", ") + (currentItems.count > 3 ? " and more" : ""),
                explanation: "Indexes, compiled caches and logs the IDE rebuilds the next time it opens a project. Settings and plugins are left alone.",
                method: .delete,
                actionTarget: "~/Library/Caches/JetBrains, ~/Library/Logs/JetBrains",
                items: currentItems,
                waitsFor: jetBrainsCheck
            ))
        }

        if !old.isEmpty {
            // An older version that still writes logs is the one actually in use, newer install or not.
            let (stillUsed, unused) = old.partitioned { install in
                guard let used = lastUsed(install) else { return false }
                return used > context.staleCutoff
            }
            for install in stillUsed {
                result.protected.append(ProtectedItem(
                    id: "ides.recent/\(install.product)\(install.version)", area: .ides,
                    title: "\(friendlyName(install.product)) \(install.version)",
                    why: "Used \(context.relative(lastUsed(install) ?? context.now)), even though a newer version is installed",
                    rule: .recentlyUsed, size: nil
                ))
            }
            let sizes = await Sizing.sizes(of: unused.flatMap(\.folders))
            var items: [FindingItem] = []
            for install in unused {
                let size = install.folders.reduce(Int64(0)) { $0 + (sizes[$1] ?? 0) }
                guard size >= 1_000_000 else { continue }
                let kinds = [install.support.map { _ in "settings" }, install.caches.map { _ in "caches" }, install.logs.map { _ in "logs" }]
                    .compactMap { $0 }.joined(separator: ", ")
                let used = lastUsed(install).map { "last used \(context.relative($0))" } ?? "not used in \(context.staleDays)+ days"
                items.append(FindingItem(
                    id: "ides.oldVersions/\(install.product)\(install.version)",
                    title: "\(friendlyName(install.product)) \(install.version)",
                    detail: "\(kinds.prefix(1).uppercased() + kinds.dropFirst()) of a version you no longer run, \(used)",
                    size: size,
                    paths: install.folders
                ))
            }
            items.sort { $0.size > $1.size }
            if !items.isEmpty {
                result.findings.append(Finding(
                    id: "ides.oldVersions",
                    area: .ides,
                    aftermath: .downloadsAgain,
                    title: "Old IDE versions",
                    summary: "\(items.count) \(items.count == 1 ? "version" : "versions") older than the one you run",
                    explanation: "Settings, caches and logs for IDE versions you no longer run. The current version of each IDE keeps its own.",
                    method: .trash,
                    actionTarget: "~/Library/Application Support/JetBrains, Caches/JetBrains, Logs/JetBrains",
                    items: items
                ))
            }
        }

        if result.findings.isEmpty {
            result.skipReason = "No IDEs or editors found."
        }
        return result
    }

    /// Every product-version with a folder somewhere under Library.
    static func installs(home: URL) -> [Install] {
        var byKey: [String: Install] = [:]
        let roots: [(folder: String, keyPath: WritableKeyPath<Install, URL?>)] = [
            ("Library/Caches/JetBrains", \.caches), ("Library/Logs/JetBrains", \.logs),
            ("Library/Application Support/JetBrains", \.support),
            ("Library/Caches/Google", \.caches), ("Library/Logs/Google", \.logs),
            ("Library/Application Support/Google", \.support),
        ]
        for root in roots {
            for folder in Files.subdirectories(of: home.appending(path: root.folder)) {
                guard let parsed = parse(folderName: folder.lastPathComponent) else { continue }
                // Only Android Studio lives under Google; Chrome and friends do not have versions in their names.
                if root.folder.hasSuffix("Google"), parsed.product != "AndroidStudio" { continue }
                let key = parsed.product + parsed.version
                var install = byKey[key] ?? Install(product: parsed.product, version: parsed.version)
                install[keyPath: root.keyPath] = folder
                byKey[key] = install
            }
        }
        return byKey.values.sorted { ($0.product, $0.version) < ($1.product, $1.version) }
    }

    /// When the IDE last wrote to this version's folders: its logs change on every launch.
    static func lastUsed(_ install: Install) -> Date? {
        install.folders.compactMap { Cleaner.newestChange(in: $0) }.max()
    }

    /// The newest version of each product, and everything older.
    static func split(_ installs: [Install]) -> (current: [Install], old: [Install]) {
        var newest: [String: String] = [:]
        for install in installs {
            if let known = newest[install.product], !isNewer(install.version, than: known) { continue }
            newest[install.product] = install.version
        }
        let current = installs.filter { newest[$0.product] == $0.version }
        let old = installs.filter { newest[$0.product] != $0.version }
        return (current, old)
    }

    /// "IntelliJIdea2025.2" -> ("IntelliJIdea", "2025.2"). Nil for a folder with no version in its name.
    static func parse(folderName: String) -> (product: String, version: String)? {
        guard let firstDigit = folderName.firstIndex(where: \.isNumber) else { return nil }
        let product = String(folderName[..<firstDigit])
        let version = String(folderName[firstDigit...])
        guard !product.isEmpty, version.allSatisfy({ $0.isNumber || $0 == "." }), !version.isEmpty else { return nil }
        return (product, version)
    }

    static func isNewer(_ version: String, than other: String) -> Bool {
        let lhs = versionKey(version)
        let rhs = versionKey(other)
        return rhs.lexicographicallyPrecedes(lhs)
    }

    private static func versionKey(_ version: String) -> [Int] {
        version.split(separator: ".").compactMap { Int($0) }
    }

    static func friendlyName(_ product: String) -> String {
        switch product {
        case "IntelliJIdea": "IntelliJ IDEA"
        case "AndroidStudio": "Android Studio"
        case "PyCharm", "WebStorm", "GoLand", "CLion", "Rider", "RubyMine", "PhpStorm", "DataGrip", "AppCode", "Fleet": product
        case "PyCharmCE": "PyCharm Community"
        case "IdeaIC": "IntelliJ IDEA Community"
        default: product
        }
    }
}
