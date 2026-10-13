//
//  ToolchainScanner.swift
//  SwiftMacCleaner
//

import Foundation

/// Lists versions installed by version managers that are not the one in use.
nonisolated enum ToolchainScanner {
    /// Candidates to offer, and the versions kept because they are the default or the newest.
    struct Report {
        var candidates: [PathCandidate] = []
        var protected: [ProtectedItem] = []

        mutating func append(_ other: Report) {
            candidates += other.candidates
            protected += other.protected
        }
    }

    static func scan(_ context: ScanContext) async -> AreaScanResult {
        let home = context.home
        var report = Report()
        report.append(sdkman(home))
        report.append(nvm(home))
        report.append(fnm(home))
        report.append(volta(home))
        report.append(versions(in: home.appending(path: "fvm/versions"), label: "Flutter", manager: "FVM",
                               inUse: linkTarget(home.appending(path: "fvm/default")).map { [$0] } ?? []))
        report.append(versions(in: home.appending(path: ".pyenv/versions"), label: "Python", manager: "pyenv",
                               inUse: lines(of: home.appending(path: ".pyenv/version"))))
        report.append(versions(in: home.appending(path: ".rbenv/versions"), label: "Ruby", manager: "rbenv",
                               inUse: lines(of: home.appending(path: ".rbenv/version"))))
        report.append(rustup(home))
        report.append(asdf(home))
        report.append(mise(home))

        var result = AreaScanResult(protected: report.protected)
        let items = await Sizing.items(prefix: "toolchains.unused", from: report.candidates, minimumSize: 20_000_000)
        guard !items.isEmpty else { return result }
        result.findings.append(Finding(
            id: "toolchains.unused",
            area: .toolchains,
            aftermath: .downloadsAgain,
            title: "Unused toolchain versions",
            summary: "\(items.count) installed \(items.count == 1 ? "version" : "versions") that \(items.count == 1 ? "is" : "are") not your default",
            explanation: "Older JDKs, Node versions and SDKs installed by version managers. A project pinned to one of them would need it installed again. The default and the newest version of each tool are never offered.",
            method: .trash,
            actionTarget: "The version folder shown in each row",
            items: items
        ))
        return result
    }

    // MARK: Managers

    private static func sdkman(_ home: URL) -> Report {
        var report = Report()
        for tool in Files.subdirectories(of: home.appending(path: ".sdkman/candidates")) {
            let current = linkTarget(tool.appending(path: "current"))
            let name = tool.lastPathComponent
            let label = name == "java" ? "Java" : name.capitalized
            for version in Files.subdirectories(of: tool) {
                if version.lastPathComponent == current {
                    report.protected.append(kept(label, version.lastPathComponent, manager: "SDKMAN", isDefault: true))
                    continue
                }
                report.candidates.append(PathCandidate(
                    title: "\(label) \(version.lastPathComponent)",
                    detail: "Installed with SDKMAN, not the current \(label) version",
                    url: version,
                    hint: "~/.sdkman/candidates/\(name)/\(version.lastPathComponent)"
                ))
            }
        }
        return report
    }

    private static func nvm(_ home: URL) -> Report {
        let folders = Files.subdirectories(of: home.appending(path: ".nvm/versions/node"))
        let alias = lines(of: home.appending(path: ".nvm/alias/default")).first ?? ""
        let inUse = nodeVersionsInUse(folders.map(\.lastPathComponent), defaultAlias: alias)
        return nodeReport(folders: folders, inUse: inUse, manager: "nvm", hintPrefix: "~/.nvm/versions/node/")
    }

    /// fnm keeps each Node under `node-versions/<version>/installation` and points `aliases/default` at one.
    private static func fnm(_ home: URL) -> Report {
        let root = home.appending(path: "Library/Application Support/fnm")
        let folders = Files.subdirectories(of: root.appending(path: "node-versions"))
        guard !folders.isEmpty else { return Report() }
        let defaultLink = root.appending(path: "aliases/default")
        // The link points at `<version>/installation`, so the version is one level up from where it lands.
        var alias = ""
        if Files.isSymlink(defaultLink) {
            let target = defaultLink.resolvingSymlinksInPath()
            alias = target.lastPathComponent == "installation" ? target.deletingLastPathComponent().lastPathComponent : target.lastPathComponent
        }
        let inUse = nodeVersionsInUse(folders.map(\.lastPathComponent), defaultAlias: alias)
        return nodeReport(folders: folders, inUse: inUse, manager: "fnm", hintPrefix: "~/Library/Application Support/fnm/node-versions/")
    }

    /// Volta keeps Node images under `tools/image/node/<version>` and names the default in platform.json.
    private static func volta(_ home: URL) -> Report {
        let folders = Files.subdirectories(of: home.appending(path: ".volta/tools/image/node"))
        guard !folders.isEmpty else { return Report() }
        let alias = voltaDefaultNode(platformJSON: home.appending(path: ".volta/tools/user/platform.json")) ?? ""
        let inUse = nodeVersionsInUse(folders.map(\.lastPathComponent), defaultAlias: alias)
        return nodeReport(folders: folders, inUse: inUse, manager: "Volta", hintPrefix: "~/.volta/tools/image/node/")
    }

    /// The `node.runtime` value from Volta's platform.json, such as "20.11.1".
    static func voltaDefaultNode(platformJSON url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let node = json["node"] as? [String: Any] else { return nil }
        return node["runtime"] as? String
    }

    private static func nodeReport(folders: [URL], inUse: Set<String>, manager: String, hintPrefix: String) -> Report {
        var report = Report()
        let newest = folders.map(\.lastPathComponent).max { versionKey($0).lexicographicallyPrecedes(versionKey($1)) }
        // The newest is kept whether or not it is the default; everything else in use is the default.
        let defaults = inUse.subtracting([newest ?? ""])
        for folder in folders {
            let version = folder.lastPathComponent
            if inUse.contains(version) {
                report.protected.append(kept("Node", version, manager: manager, isDefault: defaults.contains(version)))
                continue
            }
            report.candidates.append(PathCandidate(
                title: "Node \(version)",
                detail: "Installed with \(manager), not your default version",
                url: folder,
                hint: hintPrefix + version
            ))
        }
        return report
    }

    /// The newest version is always kept, along with whatever the default alias points at.
    static func nodeVersionsInUse(_ versions: [String], defaultAlias: String) -> Set<String> {
        var inUse = Set<String>()
        let alias = defaultAlias.hasPrefix("v") ? String(defaultAlias.dropFirst()) : defaultAlias
        if alias.first?.isNumber == true {
            inUse.formUnion(versions.filter { $0 == "v\(alias)" || $0.hasPrefix("v\(alias).") || $0 == alias || $0.hasPrefix("\(alias).") })
        }
        let newest = versions.max { versionKey($0).lexicographicallyPrecedes(versionKey($1)) }
        if let newest { inUse.insert(newest) }
        return inUse
    }

    private static func rustup(_ home: URL) -> Report {
        let settings = (try? String(contentsOf: home.appending(path: ".rustup/settings.toml"), encoding: .utf8)) ?? ""
        let defaultLine = settings.split(whereSeparator: \.isNewline).first { $0.hasPrefix("default_toolchain") }
        // Without a known default there is no telling which toolchain is in use.
        guard let name = defaultLine?.split(separator: "\"").dropFirst().first else { return Report() }
        return versions(in: home.appending(path: ".rustup/toolchains"), label: "Rust", manager: "rustup",
                        inUse: [String(name)])
    }

    /// asdf keeps `installs/<tool>/<version>` and names global defaults in `~/.tool-versions`.
    private static func asdf(_ home: URL) -> Report {
        let installs = home.appending(path: ".asdf/installs")
        guard Files.isDirectory(installs) else { return Report() }
        let defaults = toolVersions(in: lines(of: home.appending(path: ".tool-versions")))
        var report = Report()
        for tool in Files.subdirectories(of: installs) {
            let name = tool.lastPathComponent
            report.append(versions(in: tool, label: toolLabel(name), manager: "asdf", inUse: defaults[name] ?? []))
        }
        return report
    }

    /// mise keeps `installs/<tool>/<version>` plus alias symlinks, and names defaults in its config.
    private static func mise(_ home: URL) -> Report {
        let installs = home.appending(path: ".local/share/mise/installs")
        guard Files.isDirectory(installs) else { return Report() }
        let config = (try? String(contentsOf: home.appending(path: ".config/mise/config.toml"), encoding: .utf8)) ?? ""
        let defaults = miseTools(in: config)
        var report = Report()
        for tool in Files.subdirectories(of: installs) {
            let name = tool.lastPathComponent
            report.append(versions(in: tool, label: toolLabel(name), manager: "mise", inUse: defaults[name] ?? []))
        }
        return report
    }

    /// "nodejs 20.11.1 18.19.0" -> ["nodejs": ["20.11.1", "18.19.0"]].
    static func toolVersions(in lines: [String]) -> [String: [String]] {
        var defaults: [String: [String]] = [:]
        for line in lines where !line.hasPrefix("#") {
            let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count >= 2 else { continue }
            defaults[parts[0]] = Array(parts.dropFirst()).filter { !$0.hasPrefix("#") }
        }
        return defaults
    }

    /// The `[tools]` table of a mise config: `node = "20"` or `python = ["3.12", "3.11"]`.
    static func miseTools(in config: String) -> [String: [String]] {
        var defaults: [String: [String]] = [:]
        var inTools = false
        for raw in config.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") {
                inTools = line == "[tools]"
                continue
            }
            guard inTools, !line.hasPrefix("#"), let equals = line.firstIndex(of: "=") else { continue }
            let name = line[..<equals].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            let versions = line[line.index(after: equals)...]
                .split(separator: "\"")
                .enumerated()
                .filter { $0.offset % 2 == 1 }
                .map { String($0.element) }
            guard !name.isEmpty, !versions.isEmpty else { continue }
            defaults[name] = versions
        }
        return defaults
    }

    private static func versions(in folder: URL, label: String, manager: String, inUse: [String]) -> Report {
        var report = Report()
        let folders = Files.subdirectories(of: folder)
        let newest = folders.map(\.lastPathComponent).max { versionKey($0).lexicographicallyPrecedes(versionKey($1)) }
        for version in folders {
            let name = version.lastPathComponent
            let isDefault = inUse.contains { name == $0 || name.hasPrefix($0 + ".") }
            // Pinned versions always stay. So does the newest, unless a default is known for this tool.
            if isDefault || (inUse.isEmpty && name == newest) {
                report.protected.append(kept(label, name, manager: manager, isDefault: isDefault))
                continue
            }
            report.candidates.append(PathCandidate(
                title: "\(label) \(name)",
                detail: "Installed with \(manager), not your default version",
                url: version
            ))
        }
        return report
    }

    private static func kept(_ label: String, _ version: String, manager: String, isDefault: Bool) -> ProtectedItem {
        ProtectedItem(
            id: "toolchains.kept/\(manager)/\(label)/\(version)",
            area: .toolchains,
            title: "\(label) \(version)",
            why: isDefault ? "Your default \(label) version in \(manager)" : "Newest \(label) version in \(manager), kept by default",
            rule: .defaultVersion,
            size: nil
        )
    }

    /// "nodejs" -> "Node", "java" -> "Java", "python" -> "Python".
    static func toolLabel(_ name: String) -> String {
        switch name.lowercased() {
        case "nodejs", "node": "Node"
        case "java": "Java"
        case "python": "Python"
        case "ruby": "Ruby"
        case "golang", "go": "Go"
        case "rust": "Rust"
        default: name.capitalized
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
