//
//  PackageCacheScanner.swift
//  Mac Disk Cleaner
//

import Foundation

nonisolated enum PackageCacheScanner {
    /// Folders in ~/Library/Caches that belong to this area, so the general cache scan skips them.
    static var claimedCacheFolders: Set<String> { Catalog.claimedCacheFolders }

    static func scan(_ context: ScanContext) async -> AreaScanResult {
        var findings: [Finding] = []
        if let finding = await CatalogScanner.finding(for: Catalog.packageCaches, context: context) {
            findings.append(finding)
        }
        if let finding = await goModules(context) { findings.append(finding) }
        if let finding = homebrew(context) { findings.append(finding) }
        return AreaScanResult(findings: findings)
    }

    // MARK: Go

    /// The Go module cache lives wherever `go env GOMODCACHE` says, which is ~/go/pkg/mod unless moved.
    private static func goModules(_ context: ScanContext) async -> Finding? {
        let group = Catalog.goModules
        var path = context.home.appending(path: group.locations[0].path)
        if let go = Shell.which("go"),
           let output = Shell.run(go, ["env", "GOMODCACHE"], timeout: 15), output.succeeded {
            let reported = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if reported.hasPrefix("/") { path = URL(fileURLWithPath: reported, isDirectory: true) }
        }
        let location = group.locations[0]
        let candidate = PathCandidate(title: location.title, detail: location.detail, url: path,
                                      preselected: location.preselected, hint: context.tilde(path))
        let items = await Sizing.items(prefix: group.id, from: [candidate], minimumSize: group.minimumSize)
        guard !items.isEmpty else { return nil }
        return Finding(
            id: group.id, area: group.area, tier: group.tier, title: group.title,
            summary: context.tilde(path), explanation: group.explanation,
            method: group.method, actionTarget: context.tilde(path), items: items
        )
    }

    // MARK: Homebrew

    /// Asks Homebrew what `brew cleanup` would remove. The dry run is the only way to get a size.
    private static func homebrew(_ context: ScanContext) -> Finding? {
        guard let brew = Shell.which("brew") else { return nil }
        guard let output = Shell.run(brew, ["cleanup", "-n", "--prune=all"], timeout: 60), output.succeeded else { return nil }
        let size = bytes(fromCleanupOutput: output.stdout)
        guard size > 50_000_000 else { return nil }
        let removals = output.stdout.split(whereSeparator: \.isNewline).filter { $0.hasPrefix("Would remove:") }.count
        let item = FindingItem(
            id: "packages.homebrew/cleanup",
            title: "Old Homebrew versions and downloads",
            detail: removals == 1 ? "1 item brew cleanup would remove" : "\(removals) items brew cleanup would remove",
            size: size,
            command: [brew, "cleanup", "--prune=all"]
        )
        return Finding(
            id: "packages.homebrew",
            area: .packageCaches,
            tier: .safe,
            title: "Old Homebrew versions and downloads",
            summary: "What brew cleanup would remove, \(removals == 1 ? "1 item" : "\(removals) items")",
            explanation: "Outdated versions of formulae and casks Homebrew keeps after upgrades, and downloads it has already installed. brew cleanup removes them; nothing you use goes away.",
            method: .command,
            actionTarget: "brew cleanup --prune=all",
            items: [item]
        )
    }

    /// "==> This operation would free approximately 2.4GB of disk space." -> 2_400_000_000.
    /// Homebrew reports decimal units. Anything unexpected gives 0.
    static func bytes(fromCleanupOutput output: String) -> Int64 {
        let marker = "would free approximately "
        for line in output.split(whereSeparator: \.isNewline).reversed() {
            guard let range = line.range(of: marker) else { continue }
            let rest = line[range.upperBound...]
            guard let token = rest.split(separator: " ").first else { continue }
            let number = token.prefix { $0.isNumber || $0 == "." || $0 == "," }
            guard let value = Double(number.replacingOccurrences(of: ",", with: "")) else { return 0 }
            let multiplier: Double = switch token.dropFirst(number.count).uppercased() {
            case "KB": 1e3
            case "MB": 1e6
            case "GB": 1e9
            case "TB": 1e12
            case "B", "": 1
            default: 0
            }
            return Int64((value * multiplier).rounded())
        }
        return 0
    }
}
