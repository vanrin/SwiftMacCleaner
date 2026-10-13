//
//  Uninstaller.swift
//  SwiftMacCleaner
//

import Foundation

/// Turns ticked app files into a plan the cleaner can carry out. Everything goes to the Trash,
/// the app itself first, so an app that could not be moved keeps the files it needs to run.
///
/// What the app's installer left under /Library belongs to root. Those files are stopped and moved by
/// one script that runs with the user's password, last of all.
nonisolated enum Uninstaller {
    static func stepID(for app: InstalledApp) -> String { "uninstall/\(app.id)" }

    /// The id the script that moves an app's system files goes by. No file has it.
    static func systemItemID(for app: InstalledApp) -> String { "uninstall.system/\(app.id)" }

    /// One step per app that has anything ticked, in the order the apps are given.
    static func plan(for apps: [InstalledApp], selection: Set<String>,
                     home: URL = FileManager.default.homeDirectoryForCurrentUser, uid: uid_t = getuid(),
                     systemFolders: [SystemFolder] = SystemFolder.standard) -> CleanPlan {
        var plan = CleanPlan()
        for app in apps {
            // The bundle is listed first, so it is moved first.
            let files = app.files.filter { selection.contains($0.id) }
            guard !files.isEmpty else { continue }
            let removesApp = files.contains { $0.kind == .binaries }
            var operations: [CleanOperation] = []
            for file in files where !file.isSystemWide {
                // A launch agent is told to stop before its file goes, or it would run on until the next login.
                if let service = file.service {
                    operations.append(CleanOperation(
                        itemID: file.id, kind: .run(PerformancePlan.unloadCommand(for: service, uid: uid, tolerant: true))
                    ))
                }
                operations.append(CleanOperation(itemID: file.id, kind: .trash(file.url), size: file.size))
            }
            // Looked at again here, because the script runs as root and no guard stands behind it.
            let system = files.filter { $0.isSystemWide && SystemFolder.allows($0.url, in: systemFolders) }
            if !system.isEmpty {
                operations.append(CleanOperation(
                    itemID: systemItemID(for: app),
                    kind: .runAsAdmin(systemCommand(for: app, files: system, home: home, uid: uid)),
                    size: system.reduce(0) { $0 + $1.size }
                ))
            }
            guard !operations.isEmpty else { continue }
            plan.steps.append(CleanStep(
                id: stepID(for: app),
                title: removesApp ? app.name : "\(app.name): its files only",
                aftermath: .downloadsAgain,
                method: .trash,
                summary: summary(removesApp: removesApp, related: files.count - (removesApp ? 1 : 0)),
                size: files.reduce(0) { $0 + $1.size },
                operations: operations,
                waitsFor: .app(bundleID: app.bundleID, name: app.name),
                requiresFirst: removesApp
            ))
        }
        return plan
    }

    private static func summary(removesApp: Bool, related: Int) -> String {
        let items = related == 1 ? "1 related item" : "\(related) related items"
        if !removesApp { return "Move \(items) to the Trash. The app stays and starts fresh" }
        return related == 0 ? "Move the app to the Trash" : "Move the app and \(items) to the Trash"
    }

    /// The apps whose bundle is ticked, which is what the guard lets through outside the home folder.
    static func bundles(in apps: [InstalledApp], selection: Set<String>) -> [URL] {
        apps.compactMap(\.bundleFile).filter { selection.contains($0.id) }.map(\.url)
    }

    /// Whether the plan moves an app only Finder can move, in which case Finder asks for a password.
    static func needsFinder(_ apps: [InstalledApp], selection: Set<String>) -> Bool {
        apps.contains { app in app.needsPassword && app.bundleFile.map { selection.contains($0.id) } == true }
    }

    /// Whether macOS asks for a password at all: for an app only Finder can move, or for files under /Library.
    static func needsPassword(_ apps: [InstalledApp], selection: Set<String>) -> Bool {
        needsFinder(apps, selection: selection) || apps.contains { !systemFiles(of: $0, in: selection).isEmpty }
    }

    // MARK: Files under /Library

    static func systemFiles(of app: InstalledApp, in selection: Set<String>) -> [AppFile] {
        app.systemFiles.filter { selection.contains($0.id) }
    }

    /// The start of the name of the folder an app's system files are gathered in, inside the Trash.
    static func systemFolderName(for app: InstalledApp) -> String { "\(app.name) system files" }

    /// One script, run as root, that stops an app's services and moves its files under /Library into
    /// a new folder in the user's Trash, each under the name of the folder it came from.
    ///
    /// As root the script only moves files, and the one thing it changes the owner of is the folders it
    /// has just made, once everything is in them. Until then the new folder is root's, so no other
    /// program can put something in it for root to hand over. The files keep their owner, which does
    /// not stop the user from emptying the Trash.
    static func systemCommand(for app: InstalledApp, files: [AppFile], home: URL, uid: uid_t) -> [String] {
        let quote = CleanPlan.quote
        var lines = [
            "t=\(quote(home.appending(path: ".Trash").path))",
            "if [ ! -d \"$t\" ] || [ -L \"$t\" ]; then echo 'no Trash folder' >&2; exit 1; fi",
            "d=\"$t\"/\(quote(systemFolderName(for: app) + " "))\"$(/bin/date +%Y-%m-%d-%H%M%S)\"",
            "/bin/mkdir -m 755 \"$d\" || exit 1",
            "failed=''",
        ]
        for service in files.compactMap(\.service) {
            let target = "\(service.domain.launchdDomain(uid: uid))/\(service.label)"
            lines.append("/bin/launchctl bootout \(quote(target)) >/dev/null 2>&1")
        }
        var folders: [String] = []
        for (index, file) in files.enumerated() {
            let folder = file.url.deletingLastPathComponent().lastPathComponent
            if !folders.contains(folder) { folders.append(folder) }
            let destination = "\"$d\"/\(quote(folder))"
            // A file that is already gone is not a failure, and a link is never followed.
            lines.append("s=\(quote(file.url.path))")
            lines.append("if [ -f \"$s\" ] && [ ! -L \"$s\" ]; then { /bin/mkdir -p \(destination) && /bin/mv -f \"$s\" \(destination)/; } || failed=\"$failed \(index)\"; fi")
        }
        // The folders made above, innermost first, and nothing inside them.
        lines.append("/usr/sbin/chown -h \(uid) " + (folders.map { "\"$d\"/\(quote($0))" } + ["\"$d\""]).joined(separator: " ") + " 2>/dev/null")
        lines.append("if [ -n \"$failed\" ]; then echo \"failed:$failed\" >&2; exit 1; fi")
        return ["/bin/sh", "-c", lines.joined(separator: "; ")]
    }

    /// The ids of every file a run removed. One script moves all of an app's system files and reports
    /// as one item, so each of those files is looked for on disk instead: gone is what counts.
    static func removedFiles(in outcome: CleanOutcome, apps: [InstalledApp], selection: Set<String>) -> Set<String> {
        var removed = outcome.cleanedItemIDs
        for app in apps {
            removed.remove(systemItemID(for: app))
            guard let step = outcome.steps.first(where: { $0.id == stepID(for: app) }), step.skippedReason == nil else { continue }
            removed.formUnion(systemFiles(of: app, in: selection).filter { !isPresent($0.url) }.map(\.id))
        }
        return removed
    }

    /// What to say on the receipt under an app whose system files were ticked, in place of the usual
    /// sentence. Nil keeps that sentence, as when the app itself could not be moved.
    static func receiptDetail(for app: InstalledApp, step: StepOutcome, selection: Set<String>, removed: Set<String>) -> String? {
        let files = systemFiles(of: app, in: selection)
        guard !files.isEmpty, step.skippedReason == nil else { return nil }
        // When the app itself did not move, nothing after it was tried, and the usual sentence says why.
        if let bundle = app.bundleFile, selection.contains(bundle.id), !removed.contains(bundle.id) { return nil }
        let count = files.count == 1 ? "1 file" : "\(files.count) files"
        let left = files.count { !removed.contains($0.id) }
        if left == 0 {
            guard step.failures.isEmpty else { return nil }
            return "Moved to the Trash. \(count) from /Library \(files.count == 1 ? "was" : "were") stopped and moved there too, into the folder “\(systemFolderName(for: app))”. Put Back does not return \(files.count == 1 ? "that one" : "those")."
        }
        if step.failures.contains(where: { $0.contains("cancelled") }) {
            return "The password prompt was cancelled, so \(count) in /Library stayed. Everything else was moved to the Trash."
        }
        return "\(left) of \(count) in /Library could not be moved; the log has what macOS said. Everything else was moved to the Trash."
    }

    /// Whether something is at the path, a dangling link included.
    private static func isPresent(_ url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil
    }
}
