//
//  Cleaner.swift
//  SwiftMacCleaner
//

import Foundation

/// The last line of defence before anything is removed.
///
/// A path passes only when it sits well inside one of the roots, is not on the protected list,
/// does not live in iCloud, and is on the same volume as the home folder. Scanners are expected
/// to follow the same rules; the guard is there for the day one of them does not.
nonisolated struct SafetyGuard: Sendable {
    /// The home folder: the main place things are cleaned.
    var root: URL
    /// Folders outside home whose direct children may be removed, such as the per-user temp folder.
    var extraRoots: [URL] = []
    /// Application bundles that may be moved to the Trash whole, such as an Xcode that is not selected.
    var allowedApplications: [URL] = []
    /// Paths the user never wants touched, as stored in the Never Suggest list.
    var neverSuggest: [String] = []

    /// Places inside home that hold things no cleaner should ever touch, relative to home.
    static let protectedPrefixes: [String] = [
        "Library/Mobile Documents", "Library/CloudStorage", "Library/Mail", "Library/Messages",
        "Library/Keychains", "Library/Accounts", "Library/Cookies", "Library/Photos",
        "Library/Application Support/MobileSync/Backup", "Library/Application Support/AddressBook",
        "Library/Application Support/CallHistoryDB", "Library/Application Support/com.apple.sharedfilelist",
        "Library/Application Support/Knowledge", "Library/Group Containers/group.com.apple.notes",
        "Library/Containers/com.apple.mail", "Library/Containers/com.apple.Notes",
        "Library/Containers/com.apple.Photos", "Library/Containers/com.apple.MobileSMS",
        ".ssh", ".gnupg", ".aws", ".kube", ".config/gcloud", ".password-store",
    ]

    /// Folder names that mark something as a repository or a library, never to be removed or entered.
    static let protectedComponents: Set<String> = [".git", ".hg", ".svn"]
    static let protectedExtensions: Set<String> = ["photoslibrary", "aplibrary", "musiclibrary", "tvlibrary", "keychain-db"]

    /// Careful findings may name an iPhone backup explicitly; nothing else may reach into it.
    var backupsAllowed = false

    func allows(_ url: URL) -> Bool { refusal(for: url) == nil }

    /// Nil when the path may be removed, otherwise the reason it may not.
    func refusal(for url: URL) -> String? {
        let target = url.standardizedFileURL
        // Resolve the parent, not the item: a symlink is removed as a link, never followed.
        let parent = target.deletingLastPathComponent().resolvingSymlinksInPath().path
        let resolved = (parent == "/" ? "" : parent) + "/" + target.lastPathComponent
        let components = resolved.split(separator: "/").map(String.init)
        guard !components.contains(".."), !components.isEmpty else { return "outside the allowed area" }

        if isOnNeverSuggest(resolved) { return "on your Never Suggest list" }
        if let reason = structuralRefusal(resolved: resolved) { return reason }
        if let reason = contentRefusal(resolved: resolved) { return reason }
        return nil
    }

    /// Whether the user asked never to have this path, or anything it sits inside, offered.
    func isOnNeverSuggest(_ path: String) -> Bool {
        neverSuggest.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    private func structuralRefusal(resolved: String) -> String? {
        let rootPath = root.resolvingSymlinksInPath().path
        if resolved.hasPrefix(rootPath + "/") {
            let relative = Array(resolved.dropFirst(rootPath.count + 1).split(separator: "/").map(String.init))
            // Never a direct child of the root (Documents, Library, .gradle itself...).
            guard relative.count >= 2 else { return "a whole top-level folder" }
            // Inside Library, never a whole top-level folder such as Library/Caches.
            if relative[0] == "Library", relative.count < 3 { return "a whole Library folder" }
            let relativePath = relative.joined(separator: "/")
            for prefix in Self.protectedPrefixes
            where relativePath == prefix || relativePath.hasPrefix(prefix + "/") {
                if backupsAllowed, prefix.hasSuffix("MobileSync/Backup"), relative.count == 5 { continue }
                return "on the protected list"
            }
            if relative.contains(where: Self.protectedComponents.contains) { return "part of a repository" }
            if relative.contains(where: { Self.protectedExtensions.contains(($0 as NSString).pathExtension.lowercased()) }) {
                return "a library macOS manages"
            }
            return nil
        }
        for extra in extraRoots {
            let extraPath = extra.resolvingSymlinksInPath().path
            if resolved.hasPrefix(extraPath + "/") {
                let depth = resolved.dropFirst(extraPath.count + 1).split(separator: "/").count
                return depth >= 1 ? nil : "a whole temp folder"
            }
        }
        if allowedApplications.contains(where: { $0.standardizedFileURL.path == resolved }) {
            return nil
        }
        return "outside the allowed area"
    }

    /// Rules that need a look at the item itself. A path that does not exist is left to the caller.
    private func contentRefusal(resolved: String) -> String? {
        let url = URL(fileURLWithPath: resolved)
        guard let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey, .volumeIdentifierKey]) else {
            return nil
        }
        if values.isUbiquitousItem == true { return "kept in iCloud" }
        if let volume = values.volumeIdentifier as? NSObject,
           let home = (try? root.resourceValues(forKeys: [.volumeIdentifierKey]))?.volumeIdentifier as? NSObject,
           !volume.isEqual(home) {
            return "on another disk"
        }
        return nil
    }
}

nonisolated struct CleanProgress: Sendable, Equatable {
    var fraction: Double
    var status: String
}

/// Where something moved to the Trash came from, so it can be put back.
nonisolated struct TrashedItem: Sendable, Codable, Hashable {
    var original: URL
    var inTrash: URL
    var size: Int64
}

nonisolated struct StepOutcome: Identifiable, Sendable {
    var id: String
    var title: String
    var method: CleanMethod
    var size: Int64
    var cleanedItemIDs: [String]
    var failures: [String]
    /// Items left alone because they changed after the scan, with the sentence for the receipt.
    var skippedItems: [String: String] = [:]
    var skippedReason: String?
    var trashed: [TrashedItem] = []

    var succeeded: Bool { failures.isEmpty && skippedReason == nil && skippedItems.isEmpty }
}

nonisolated struct CleanOutcome: Sendable {
    var steps: [StepOutcome]
    var freeBefore: Int64
    var freeAfter: Int64
    var trashedSize: Int64
    var duration: TimeInterval
    var logURL: URL?
    var started: Date

    /// What the volume actually gained, which is the only number worth promising.
    var reclaimed: Int64 { max(0, freeAfter - freeBefore) }
    var failureCount: Int { steps.reduce(0) { $0 + $1.failures.count } }
    var cleanedItemIDs: Set<String> { Set(steps.flatMap(\.cleanedItemIDs)) }
    var trashed: [TrashedItem] { steps.flatMap(\.trashed) }
    var skippedSize: Int64 { steps.filter { $0.skippedReason != nil }.reduce(0) { $0 + $1.size } }
}

nonisolated enum CleanLog {
    static let folderName = "SwiftMacCleaner"

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
    /// `scannedAt` is when the findings were measured: anything changed since is left alone too.
    @concurrent
    static func run(
        plan: CleanPlan,
        safety: SafetyGuard,
        skipping: [String: String] = [:],
        scannedAt: Date? = nil,
        progress: @escaping @Sendable (CleanProgress) -> Void
    ) async -> CleanOutcome {
        let started = Date()
        let freeBefore = DiskInfo.current(for: safety.root).free
        var log = ["SwiftMacCleaner clean-up, \(started.formatted(date: .abbreviated, time: .standard))"]
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

            var outcome = StepOutcome(id: step.id, title: step.title, method: step.method, size: step.size,
                                      cleanedItemIDs: [], failures: [], skippedReason: nil)
            var failedItems = Set<String>()
            // The freshness check runs per item, so an item with several paths is left whole or removed whole.
            if let scannedAt {
                for operation in step.operations where outcome.skippedItems[operation.itemID] == nil {
                    if let change = changedSinceScan(operation, scannedAt: scannedAt) {
                        outcome.skippedItems[operation.itemID] = change
                        failedItems.insert(operation.itemID)
                        log.append("skipped \(change)")
                    }
                }
            }
            for (index, operation) in step.operations.enumerated() {
                if Task.isCancelled {
                    outcome.failures.append("Stopped before finishing")
                    failedItems.formUnion(step.operations.map(\.itemID))
                    break
                }
                if outcome.skippedItems[operation.itemID] != nil {
                    finished += 1
                    continue
                }
                var failed = false
                do {
                    switch perform(operation, safety: safety) {
                    case .failed(let failure):
                        outcome.failures.append(failure)
                        failedItems.insert(operation.itemID)
                        log.append("FAILED  \(failure)")
                        failed = true
                    case .trashed(let item):
                        outcome.trashed.append(item)
                        log.append("ok      trashed \(item.original.path) -> \(item.inTrash.path)")
                    case .done:
                        log.append("ok      \(describe(operation))")
                    }
                }
                finished += 1
                progress(CleanProgress(fraction: Double(finished) / Double(operationCount), status: step.title))
                if failed, index == 0, step.requiresFirst {
                    let rest = step.operations.dropFirst()
                    failedItems.formUnion(rest.map(\.itemID))
                    finished += rest.count
                    log.append("left    \(rest.count) related items where they are")
                    break
                }
            }

            for operation in step.operations
            where !failedItems.contains(operation.itemID) && !outcome.cleanedItemIDs.contains(operation.itemID) {
                outcome.cleanedItemIDs.append(operation.itemID)
            }
            outcomes.append(outcome)
        }

        let freeAfter = DiskInfo.current(for: safety.root).free
        log.append("")
        log.append("Free space: \(ByteFormat.string(freeBefore)) before, \(ByteFormat.string(freeAfter)) after")
        return CleanOutcome(
            steps: outcomes,
            freeBefore: freeBefore,
            freeAfter: freeAfter,
            trashedSize: outcomes.flatMap(\.trashed).reduce(0) { $0 + $1.size },
            duration: Date().timeIntervalSince(started),
            logURL: CleanLog.write(log, home: safety.root, date: started),
            started: started
        )
    }

    /// The freshness check: a sentence when the item, or anything directly inside it, changed after the scan.
    static func changedSinceScan(_ operation: CleanOperation, scannedAt: Date) -> String? {
        let url: URL
        switch operation.kind {
        case .delete(let target), .trash(let target): url = target
        case .run, .runAsAdmin: return nil
        }
        guard let newest = newestChange(in: url), newest > scannedAt.addingTimeInterval(1) else { return nil }
        return "\(url.path): changed since the scan, so it was left alone"
    }

    /// The newest modification date anywhere inside the item. An app writing deep inside a folder
    /// counts as a change to the folder; the walk is bounded so a huge tree stays cheap.
    static func newestChange(in url: URL) -> Date? {
        Files.newestModification(in: url)
    }

    enum Result: Sendable {
        case done
        case trashed(TrashedItem)
        case failed(String)

        /// The sentence describing what went wrong, or nil when the operation went through.
        var failure: String? {
            if case .failed(let reason) = self { return reason }
            return nil
        }
    }

    /// Carries out one operation and says what happened.
    static func perform(_ operation: CleanOperation, safety: SafetyGuard) -> Result {
        let fileManager = FileManager.default
        switch operation.kind {
        case .delete(let url):
            if let reason = safety.refusal(for: url) { return .failed("Refused to delete \(url.path): \(reason)") }
            // attributesOfItem does not follow a final symlink, so a dangling link still counts as present.
            guard (try? fileManager.attributesOfItem(atPath: url.path)) != nil else { return .done }
            do {
                try fileManager.removeItem(at: url)
                return .done
            } catch {
                // Some caches are written read-only; open them up and try once more.
                makeWritable(url)
                do {
                    try fileManager.removeItem(at: url)
                    return .done
                } catch {
                    return .failed("Could not delete \(url.path): \(error.localizedDescription)")
                }
            }
        case .trash(let url):
            if let reason = safety.refusal(for: url) { return .failed("Refused to move \(url.path): \(reason)") }
            guard (try? fileManager.attributesOfItem(atPath: url.path)) != nil else { return .done }
            do {
                var destination: NSURL?
                try fileManager.trashItem(at: url, resultingItemURL: &destination)
                guard let destination else { return .done }
                return .trashed(TrashedItem(original: url, inTrash: destination as URL, size: operation.size))
            } catch {
                // An app that belongs to root, or that macOS guards, is one Finder can still move.
                guard url.pathExtension == "app", isPermissionFailure(error) else {
                    return .failed("Could not move \(url.path) to the Trash: \(error.localizedDescription)")
                }
                switch FinderTrash.move(url) {
                case .trashed(let destination?):
                    return .trashed(TrashedItem(original: url, inTrash: destination, size: operation.size))
                case .trashed(nil):
                    return .done
                case .failed(let reason):
                    return .failed(reason)
                }
            }
        case .run(let command):
            return runCommand(command, asAdmin: false)
        case .runAsAdmin(let command):
            return runCommand(command, asAdmin: true)
        }
    }

    /// True when macOS refused to let this user or this app move the item, as opposed to any other failure.
    static func isPermissionFailure(_ error: Error) -> Bool {
        let error = error as NSError
        if error.domain == NSCocoaErrorDomain,
           error.code == NSFileWriteNoPermissionError || error.code == NSFileReadNoPermissionError { return true }
        let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError
        return [error, underlying].compactMap { $0 }.contains {
            $0.domain == NSPOSIXErrorDomain && ($0.code == Int(EPERM) || $0.code == Int(EACCES))
        }
    }

    private static func runCommand(_ command: [String], asAdmin: Bool) -> Result {
        guard let executable = command.first else { return .failed("Empty command") }
        // A script is named by its shell alone; the log keeps the script itself.
        let text = executable.hasSuffix("/sh") ? "sh"
            : command.map { URL(fileURLWithPath: $0).lastPathComponent == $0 ? $0 : URL(fileURLWithPath: $0).lastPathComponent }
                .joined(separator: " ")
        let output: Shell.Output?
        if asAdmin {
            output = Shell.runAsAdministrator(command, timeout: 600)
        } else {
            output = Shell.run(executable, Array(command.dropFirst()), timeout: 600)
        }
        guard let output else { return .failed("Could not start \(text)") }
        if output.cancelled { return .failed("\(text) was stopped before it finished") }
        if output.timedOut { return .failed("\(text) did not finish in time") }
        if output.status != 0 {
            let reason = output.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if asAdmin, reason.contains("-128") { return .failed("\(text) was skipped: the password prompt was cancelled") }
            return .failed("\(text) failed" + (reason.isEmpty ? "" : ": \(reason)"))
        }
        return .done
    }

    private static func describe(_ operation: CleanOperation) -> String {
        switch operation.kind {
        case .delete(let url): "deleted \(url.path)"
        case .trash(let url): "trashed \(url.path)"
        case .run(let command): "ran \(command.joined(separator: " "))"
        case .runAsAdmin(let command): "ran as administrator \(command.joined(separator: " "))"
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

/// Puts back what the last clean moved to the Trash, as long as the Trash has not been emptied.
nonisolated enum PutBack {
    static let manifestName = "last-clean.json"

    nonisolated struct Manifest: Codable, Sendable {
        var date: Date
        var items: [TrashedItem]
    }

    static func manifestURL(home: URL) -> URL {
        home.appending(path: "Library/Application Support").appending(path: CleanLog.folderName).appending(path: manifestName)
    }

    /// Records what this clean trashed, keeping whatever an earlier clean trashed that is still in the Trash.
    static func save(_ outcome: CleanOutcome, home: URL) {
        let url = manifestURL(home: home)
        let earlier = pending(home: home)?.items.filter { item in !outcome.trashed.contains { $0.inTrash == item.inTrash } } ?? []
        let manifest = Manifest(date: outcome.started, items: earlier + outcome.trashed)
        guard !manifest.items.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(manifest).write(to: url)
    }

    /// The items from the last clean that are still waiting in the Trash.
    static func pending(home: URL) -> Manifest? {
        guard let data = try? Data(contentsOf: manifestURL(home: home)),
              var manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { return nil }
        manifest.items.removeAll { !Files.exists($0.inTrash) }
        return manifest.items.isEmpty ? nil : manifest
    }

    /// Moves every item back where it was. Returns the ones it could not restore, with the reason.
    static func restore(_ manifest: Manifest, home: URL) -> [String] {
        var failures: [String] = []
        var remaining: [TrashedItem] = []
        let fileManager = FileManager.default
        for item in manifest.items {
            guard Files.exists(item.inTrash) else { continue }
            if Files.exists(item.original) {
                failures.append("\(item.original.path) already exists, so the copy in the Trash was left there")
                remaining.append(item)
                continue
            }
            do {
                try fileManager.createDirectory(at: item.original.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.moveItem(at: item.inTrash, to: item.original)
            } catch {
                failures.append("Could not put back \(item.original.path): \(error.localizedDescription)")
                remaining.append(item)
            }
        }
        let url = manifestURL(home: home)
        if remaining.isEmpty {
            try? fileManager.removeItem(at: url)
        } else {
            try? JSONEncoder().encode(Manifest(date: manifest.date, items: remaining)).write(to: url)
        }
        return failures
    }
}
