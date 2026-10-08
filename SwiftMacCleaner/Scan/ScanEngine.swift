//
//  ScanEngine.swift
//  SwiftMacCleaner
//

import Foundation

nonisolated enum ScanEvent: Sendable {
    case started(Area)
    case finished(Area, AreaScanResult)
}

nonisolated enum ScanEngine {
    /// Scans the given areas side by side, reporting each one as it starts and finishes.
    /// Scanning only reads and measures. Ending the stream early cancels the scan.
    static func events(areas: [Area], context: ScanContext) -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                await withTaskGroup(of: Void.self) { group in
                    for area in areas {
                        group.addTask {
                            continuation.yield(.started(area))
                            let result = await scan(area, context: context)
                            continuation.yield(.finished(area, result))
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    @concurrent
    static func scan(_ area: Area, context: ScanContext) async -> AreaScanResult {
        let result: AreaScanResult = switch area {
        case .xcode: await XcodeScanner.scan(context)
        case .projects: await ProjectScanner.scan(context)
        case .android: await AndroidScanner.scan(context)
        case .containers: await ContainersScanner.scan(context)
        case .packageCaches: await PackageCacheScanner.scan(context)
        case .toolchains: await ToolchainScanner.scan(context)
        case .ides: await IDEScanner.scan(context)
        case .models: await ModelsScanner.scan(context)
        case .cachesLogs: await CachesLogsScanner.scan(context)
        case .trash: await TrashScanner.scan(context)
        case .snapshots: await SnapshotScanner.scan(context)
        case .largeFiles: await LargeFileScanner.scan(context)
        case .leftovers: await LeftoverScanner.scan(context)
        case .installers: await InstallerScanner.scan(context)
        }
        return applyingExclusions(to: result, context: context)
    }

    /// Moves anything on the Never Suggest list out of the findings and into the protected list,
    /// so no scanner has to remember the rule and the user still sees what it is hiding.
    static func applyingExclusions(to result: AreaScanResult, context: ScanContext) -> AreaScanResult {
        guard !context.excluded.isEmpty else { return result }
        var result = result
        var findings: [Finding] = []
        for var finding in result.findings {
            let (excluded, kept) = finding.items.partitioned { item in
                item.paths.contains(where: context.isExcluded) || context.excluded.contains(item.id)
            }
            for item in excluded {
                result.protected.append(ProtectedItem(
                    id: "never/\(item.id)", area: finding.area, title: item.title,
                    why: "\(item.detail.prefix(80)). On your Never Suggest list", rule: .neverSuggest,
                    size: item.sizeUnknown ? nil : item.size
                ))
            }
            finding.items = kept
            if !kept.isEmpty { findings.append(finding) }
        }
        result.findings = findings
        return result
    }
}

nonisolated extension Array {
    /// Splits the array into the elements that match and the ones that do not, keeping order.
    func partitioned(by matches: (Element) -> Bool) -> (matching: [Element], rest: [Element]) {
        var matching: [Element] = []
        var rest: [Element] = []
        for element in self {
            if matches(element) { matching.append(element) } else { rest.append(element) }
        }
        return (matching, rest)
    }
}

/// Checks whether something a finding waits for is running right now.
nonisolated enum InUse {
    static func isActive(_ check: InUseCheck) -> Bool {
        switch check {
        case .app(let bundleID, _):
            return RunningApps.isRunning(bundleID: bundleID)
        case .process(let pattern, _, _):
            guard let output = Shell.run("/usr/bin/pgrep", ["-f", pattern], timeout: 5) else { return false }
            return output.status == 0 && !output.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
