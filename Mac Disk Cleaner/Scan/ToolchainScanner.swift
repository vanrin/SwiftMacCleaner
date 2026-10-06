//
//  ToolchainScanner.swift
//  Mac Disk Cleaner
//

import Foundation

/// Lists versions installed by version managers that are not the one in use.
nonisolated enum ToolchainScanner {
    static func scan(_ context: ScanContext) async -> AreaScanResult {
        let home = context.home
        var candidates = sdkman(home) + nvm(home)
        candidates += versions(in: home.appending(path: "fvm/versions"), label: "Flutter", manager: "FVM",
                               inUse: linkTarget(home.appending(path: "fvm/default")).map { [$0] } ?? [])
        candidates += versions(in: home.appending(path: ".pyenv/versions"), label: "Python", manager: "pyenv",
                               inUse: lines(of: home.appending(path: ".pyenv/version")))
        candidates += versions(in: home.appending(path: ".rbenv/versions"), label: "Ruby", manager: "rbenv",
                               inUse: lines(of: home.appending(path: ".rbenv/version")))
        candidates += rustup(home)

        let items = await Sizing.items(prefix: "toolchains.unused", from: candidates, minimumSize: 20_000_000)
        guard !items.isEmpty else { return AreaScanResult() }
        let finding = Finding(
            id: "toolchains.unused",
            area: .toolchains,
            tier: .review,
            title: "Unused toolchain versions",
            summary: "\(items.count) installed \(items.count == 1 ? "version" : "versions") that \(items.count == 1 ? "is" : "are") not your default",
            explanation: "Older JDKs, Node versions and SDKs installed by version managers. A project pinned to one of them would need it installed again.",
            method: .trash,
            actionTarget: "The version folder shown in each row",
            items: items
        )
        return AreaScanResult(findings: [finding])
    }

    private static func sdkman(_ home: URL) -> [PathCandidate] {
        var candidates: [PathCandidate] = []
        for tool in Files.subdirectories(of: home.appending(path: ".sdkman/candidates")) {
            let current = linkTarget(tool.appending(path: "current"))
            let name = tool.lastPathComponent
            let label = name == "java" ? "Java" : name.capitalized
            for version in Files.subdirectories(of: tool) where version.lastPathComponent != current {
                candidates.append(PathCandidate(
                    title: "\(label) \(version.lastPathComponent)",
                    detail: "Installed with SDKMAN, not the current \(label) version",
                    url: version,
                    hint: "~/.sdkman/candidates/\(name)/\(version.lastPathComponent)"
                ))
            }
        }
        return candidates
    }

    private static func nvm(_ home: URL) -> [PathCandidate] {
        let folders = Files.subdirectories(of: home.appending(path: ".nvm/versions/node"))
        let alias = lines(of: home.appending(path: ".nvm/alias/default")).first ?? ""
        let inUse = nodeVersionsInUse(folders.map(\.lastPathComponent), defaultAlias: alias)
        return folders.filter { !inUse.contains($0.lastPathComponent) }.map {
            PathCandidate(
                title: "Node \($0.lastPathComponent)",
                detail: "Installed with nvm, not your default version",
                url: $0,
                hint: "~/.nvm/versions/node/\($0.lastPathComponent)"
            )
        }
    }

    /// The newest version is always kept, along with whatever the default alias points at.
    static func nodeVersionsInUse(_ versions: [String], defaultAlias: String) -> Set<String> {
        var inUse = Set<String>()
        let alias = defaultAlias.hasPrefix("v") ? String(defaultAlias.dropFirst()) : defaultAlias
        if alias.first?.isNumber == true {
            inUse.formUnion(versions.filter { $0 == "v\(alias)" || $0.hasPrefix("v\(alias).") })
        }
        let newest = versions.max { versionKey($0).lexicographicallyPrecedes(versionKey($1)) }
        if let newest { inUse.insert(newest) }
        return inUse
    }

    private static func rustup(_ home: URL) -> [PathCandidate] {
        let settings = (try? String(contentsOf: home.appending(path: ".rustup/settings.toml"), encoding: .utf8)) ?? ""
        let defaultLine = settings.split(whereSeparator: \.isNewline).first { $0.hasPrefix("default_toolchain") }
        // Without a known default there is no telling which toolchain is in use.
        guard let name = defaultLine?.split(separator: "\"").dropFirst().first else { return [] }
        return versions(in: home.appending(path: ".rustup/toolchains"), label: "Rust", manager: "rustup",
                        inUse: [String(name)])
    }

    private static func versions(in folder: URL, label: String, manager: String, inUse: [String]) -> [PathCandidate] {
        Files.subdirectories(of: folder)
            .filter { !inUse.contains($0.lastPathComponent) }
            .map {
                PathCandidate(title: "\(label) \($0.lastPathComponent)",
                              detail: "Installed with \(manager), not your default version", url: $0)
            }
    }

    private static func linkTarget(_ link: URL) -> String? {
        guard Files.isSymlink(link) else { return nil }
        return link.resolvingSymlinksInPath().lastPathComponent
    }

    private static func lines(of file: URL) -> [String] {
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func versionKey(_ name: String) -> [Int] {
        name.drop { !$0.isNumber }.split(separator: ".").compactMap { Int($0.prefix { $0.isNumber }) }
    }
}
