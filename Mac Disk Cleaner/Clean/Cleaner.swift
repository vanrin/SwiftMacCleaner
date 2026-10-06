//
//  Cleaner.swift
//  Mac Disk Cleaner
//

import Foundation

/// The last line of defence before anything is removed: only paths well inside `root` pass.
nonisolated struct SafetyGuard: Sendable {
    var root: URL

    func allows(_ url: URL) -> Bool {
        let rootPath = root.resolvingSymlinksInPath().path
        let target = url.standardizedFileURL
        // Resolve the parent, not the item: a symlink is removed as a link, never followed.
        let parent = target.deletingLastPathComponent().resolvingSymlinksInPath().path
        let resolved = (parent == "/" ? "" : parent) + "/" + target.lastPathComponent
        guard resolved.hasPrefix(rootPath + "/") else { return false }

        let components = resolved.dropFirst(rootPath.count + 1).split(separator: "/")
        // Never a direct child of the root (Documents, Library, .gradle itself...).
        guard components.count >= 2, !components.contains("..") else { return false }
        // Inside Library, never a whole top-level folder such as Library/Caches.
        if components[0] == "Library", components.count < 3 { return false }
        return true
    }
}

nonisolated struct CleanProgress: Sendable, Equatable {
    var fraction: Double
    var status: String
}

nonisolated struct StepOutcome: Identifiable, Sendable {
    var id: String
    var title: String
    var method: CleanMethod
    var size: Int64
    var cleanedItemIDs: [String]
    var failures: [String]
    var skippedReason: String?

    var succeeded: Bool { failures.isEmpty && skippedReason == nil }
}

nonisolated struct CleanOutcome: Sendable {
    var steps: [StepOutcome]
    var freeBefore: Int64
    var freeAfter: Int64
    var trashedSize: Int64
    var duration: TimeInterval
    var logURL: URL?

    /// What the volume actually gained, which is the only number worth promising.
    var reclaimed: Int64 { max(0, freeAfter - freeBefore) }
    var failureCount: Int { steps.reduce(0) { $0 + $1.failures.count } }
    var cleanedItemIDs: Set<String> { Set(steps.flatMap(\.cleanedItemIDs)) }
}

nonisolated enum CleanLog {
    static let folderName = "Mac Disk Cleaner"

    static func write(_ lines: [String], home: URL, date: Date) -> URL? {
        let folder = home.appending(path: "Library/Logs").appending(path: folderName)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let file = folder.appending(path: "clean-\(formatter.string(from: date)).log")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try lines.joined(separator: "\n").appending("\n").write(to: file, atomically: true, encoding: .utf8)
            return file
        } catch {
            return nil
        }
    }
}

nonisolated enum Cleaner {
    /// Carries out the plan. `skipping` maps step ids to the reason they must be left alone.
    @concurrent
    static func run(
        plan: CleanPlan,
        safety: SafetyGuard,
        skipping: [String: String] = [:],
        progress: @escaping @Sendable (CleanProgress) -> Void
    ) async -> CleanOutcome {
        let started = Date()
        let freeBefore = DiskInfo.current(for: safety.root).free
        var log = ["Mac Disk Cleaner clean-up, \(started.formatted(date: .abbreviated, time: .standard))"]
        var outcomes: [StepOutcome] = []
        let operationCount = max(1, plan.steps.reduce(0) { $0 + $1.operations.count })
        var finished = 0

        for step in plan.steps {
            log.append("")
            log.append("== \(step.title) (\(ByteFormat.string(step.size)))")
            if let reason = skipping[step.id] {
                log.append("skipped: \(reason)")
                finished += step.operations.count
                outcomes.append(StepOutcome(id: step.id, title: step.title, method: step.method, size: step.size,
                                            cleanedItemIDs: [], failures: [], skippedReason: reason))
                continue
            }
            progress(CleanProgress(fraction: Double(finished) / Double(operationCount), status: step.title))

            var failures: [String] = []
            var failedItems = Set<String>()
            for operation in step.operations {
                if Task.isCancelled {
                    failures.append("Stopped before finishing")
                    failedItems.formUnion(step.operations.map(\.itemID))
                    break
                }
                if let failure = perform(operation, safety: safety) {
                    failures.append(failure)
                    failedItems.insert(operation.itemID)
                    log.append("FAILED  \(failure)")
                } else {
                    log.append("ok      \(describe(operation))")
                }
                finished += 1
                progress(CleanProgress(fraction: Double(finished) / Double(operationCount), status: step.title))
            }

            var cleaned: [String] = []
            for operation in step.operations where !failedItems.contains(operation.itemID) && !cleaned.contains(operation.itemID) {
                cleaned.append(operation.itemID)
            }
            outcomes.append(StepOutcome(id: step.id, title: step.title, method: step.method, size: step.size,
                                        cleanedItemIDs: cleaned, failures: failures, skippedReason: nil))
        }

        let freeAfter = DiskInfo.current(for: safety.root).free
        log.append("")
        log.append("Free space: \(ByteFormat.string(freeBefore)) before, \(ByteFormat.string(freeAfter)) after")
        return CleanOutcome(
            steps: outcomes,
            freeBefore: freeBefore,
            freeAfter: freeAfter,
            trashedSize: outcomes.filter { $0.method == .trash && $0.skippedReason == nil }.reduce(0) { $0 + $1.size },
            duration: Date().timeIntervalSince(started),
            logURL: CleanLog.write(log, home: safety.root, date: started)
        )
    }

    /// Returns `nil` on success, or a sentence describing what went wrong.
    static func perform(_ operation: CleanOperation, safety: SafetyGuard) -> String? {
        let fileManager = FileManager.default
        switch operation.kind {
        case .delete(let url):
            guard safety.allows(url) else { return "Refused to delete \(url.path): outside the allowed area" }
            // attributesOfItem does not follow a final symlink, so a dangling link still counts as present.
            guard (try? fileManager.attributesOfItem(atPath: url.path)) != nil else { return nil }
            do {
                try fileManager.removeItem(at: url)
                return nil
            } catch {
                // Some caches are written read-only; open them up and try once more.
                makeWritable(url)
                do {
                    try fileManager.removeItem(at: url)
                    return nil
                } catch {
                    return "Could not delete \(url.path): \(error.localizedDescription)"
                }
            }
        case .trash(let url):
            guard safety.allows(url) else { return "Refused to move \(url.path): outside the allowed area" }
            guard (try? fileManager.attributesOfItem(atPath: url.path)) != nil else { return nil }
            do {
                try fileManager.trashItem(at: url, resultingItemURL: nil)
                return nil
            } catch {
                return "Could not move \(url.path) to the Trash: \(error.localizedDescription)"
            }
        case .run(let command):
            guard let executable = command.first else { return "Empty command" }
            let text = command.map { ($0 as NSString).lastPathComponent == $0 ? $0 : URL(fileURLWithPath: $0).lastPathComponent }
                .joined(separator: " ")
            guard let output = Shell.run(executable, Array(command.dropFirst()), timeout: 600) else {
                return "Could not start \(text)"
            }
            if output.timedOut { return "\(text) did not finish in time" }
            if output.status != 0 {
                let reason = output.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                return "\(text) failed" + (reason.isEmpty ? "" : ": \(reason)")
            }
            return nil
        }
    }

    private static func describe(_ operation: CleanOperation) -> String {
        switch operation.kind {
        case .delete(let url): "deleted \(url.path)"
        case .trash(let url): "trashed \(url.path)"
        case .run(let command): "ran \(command.joined(separator: " "))"
        }
    }

    private static func makeWritable(_ url: URL) {
        let fileManager = FileManager.default
        let owner: NSNumber = 0o700
        try? fileManager.setAttributes([.posixPermissions: owner], ofItemAtPath: url.path)
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: []) else { return }
        for case let child as URL in enumerator where (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
            try? fileManager.setAttributes([.posixPermissions: owner], ofItemAtPath: child.path)
        }
    }
}
