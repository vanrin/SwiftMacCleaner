//
//  ScanEngine.swift
//  Mac Disk Cleaner
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
        switch area {
        case .xcode: await XcodeScanner.scan(context)
        case .projects: await ProjectScanner.scan(context)
        case .android: await AndroidScanner.scan(context)
        case .docker: await DockerScanner.scan(context)
        case .packageCaches: await PackageCacheScanner.scan(context)
        case .toolchains: await ToolchainScanner.scan(context)
        case .cachesLogs: await CachesLogsScanner.scan(context)
        case .installersTrash: await InstallersTrashScanner.scan(context)
        }
    }
}
