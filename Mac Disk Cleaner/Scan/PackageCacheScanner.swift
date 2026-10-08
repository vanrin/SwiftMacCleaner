//
//  PackageCacheScanner.swift
//  Mac Disk Cleaner
//

import Foundation

nonisolated enum PackageCacheScanner {
    /// Folders in ~/Library/Caches that belong to this area, so the general cache scan skips them.
    static var claimedCacheFolders: Set<String> { Catalog.claimedCacheFolders }

    static func scan(_ context: ScanContext) async -> AreaScanResult {
        var result = AreaScanResult()
        // Each package manager is also asked where its cache is, for the Mac where it was moved.
        for group in [Catalog.packageCaches, Catalog.goModules] {
            let report = await CatalogScanner.report(for: group, context: context)
            result.findings += report.findings
            result.protected += report.protected
        }
        if let finding = homebrew(context) { result.findings.append(finding) }
        return result
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
