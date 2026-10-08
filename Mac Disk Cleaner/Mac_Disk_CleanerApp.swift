//
//  Mac_Disk_CleanerApp.swift
//  Mac Disk Cleaner
//
//  Created by Chhea Vanrin on 6/10/26.
//

import SwiftUI

@main
enum Launcher {
    static func main() {
        #if DEBUG
        // `Mac Disk Cleaner --print-scan [area ...]` prints what a scan finds and exits.
        if let flag = CommandLine.arguments.firstIndex(of: "--print-scan") {
            ScanReportPrinter.run(areaNames: Array(CommandLine.arguments.dropFirst(flag + 1)))
            return
        }
        // `Mac Disk Cleaner --quick-clean` does what the Quick Clean button does, from the terminal:
        // scans, ticks only the Safe tier, applies every check the app applies, cleans, prints the receipt.
        if CommandLine.arguments.contains("--quick-clean") {
            ScanReportPrinter.quickClean()
            return
        }
        // `Mac Disk Cleaner --print-stack` prints which developer tools were found, and what the login shell says.
        if CommandLine.arguments.contains("--print-stack") {
            ScanReportPrinter.printStack()
            return
        }
        // `Mac Disk Cleaner --print-apps [name] [--updates]` prints the installed apps and the files each one
        // keeps, for the apps whose name contains `name`. With `--updates` the update feeds are asked too.
        if let flag = CommandLine.arguments.firstIndex(of: "--print-apps") {
            let rest = Array(CommandLine.arguments.dropFirst(flag + 1))
            ScanReportPrinter.printApps(matching: rest.first { !$0.hasPrefix("--") }, updates: rest.contains("--updates"))
            return
        }
        // `Mac Disk Cleaner --uninstall <path to an app>` does what the Uninstall button does for that one app,
        // from the terminal: the same plan, the same guard, the same log. It really moves the app to the Trash.
        if let flag = CommandLine.arguments.firstIndex(of: "--uninstall"),
           let path = CommandLine.arguments.dropFirst(flag + 1).first {
            ScanReportPrinter.uninstall(appAt: path)
            return
        }
        // `Mac Disk Cleaner --print-space <folder>` prints the largest folders inside it and exits.
        if let flag = CommandLine.arguments.firstIndex(of: "--print-space"),
           let folder = CommandLine.arguments.dropFirst(flag + 1).first {
            ScanReportPrinter.printSpace(folder: folder)
            return
        }
        #endif
        Mac_Disk_CleanerApp.main()
    }
}

struct Mac_Disk_CleanerApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        @Bindable var settings = model.settings
        Window("Mac Disk Cleaner", id: "main") {
            RootView()
                .environment(model)
                .task { model.startBackgroundChecks() }
        }
        .defaultSize(width: 1200, height: 760)

        Settings {
            SettingsView()
                .environment(model)
        }

        MenuBarExtra("Mac Disk Cleaner", systemImage: "internaldrive", isInserted: $settings.showsMenuBarItem) {
            MenuBarView()
                .environment(model)
        }
        .menuBarExtraStyle(.window)
    }
}

#if DEBUG
/// Runs the scanners without any window, for checking them against a real disk. Nothing is removed.
nonisolated enum ScanReportPrinter {
    static func run(areaNames: [String]) {
        let requested = areaNames.compactMap(Area.init(rawValue:))
        // Downloads, the Trash and device backups raise permission prompts, so those areas are only scanned when asked for.
        let prompting: Set<Area> = [.installersTrash, .leftovers, .snapshots]
        let areas = requested.isEmpty ? Area.allCases.filter { !prompting.contains($0) } : requested
        var context = AppSettings().scanContext()
        context.shell = ShellEnvironment.loading()

        let finished = DispatchSemaphore(value: 0)
        Task.detached {
            var total: Int64 = 0
            var protectedTotal: Int64 = 0
            for area in areas {
                let started = Date()
                let result = await ScanEngine.scan(area, context: context)
                let seconds = String(format: "%.1f", Date().timeIntervalSince(started))
                print("\n## \(area.title)  (\(seconds) s)")
                if let reason = result.skipReason { print("   skipped: \(reason)") }
                for finding in result.findings {
                    total += finding.size
                    let size = finding.hasUnknownSize && finding.size == 0 ? "size unknown" : ByteFormat.string(finding.size)
                    let waits = finding.waitsFor.map { "  (waits for \($0.name))" } ?? ""
                    print("   [\(finding.tier.label)] \(finding.title): \(size) in \(finding.items.count) items, \(finding.method.verb.lowercased())\(waits)")
                    for item in finding.items.prefix(6) {
                        let itemSize = item.sizeUnknown ? "unknown" : ByteFormat.string(item.size)
                        print("      \(itemSize.padding(toLength: 9, withPad: " ", startingAt: 0)) \(item.title)  |  \(item.detail)")
                    }
                    if let note = finding.note { print("      note: \(note)") }
                }
                for item in result.protected {
                    protectedTotal += item.size ?? 0
                    let size = item.size.map(ByteFormat.string) ?? "kept"
                    print("   [Protected: \(item.rule.rawValue)] \(item.title): \(size)  |  \(item.why)")
                }
            }
            print("\nTotal found: \(ByteFormat.string(total)), left alone on purpose: \(ByteFormat.string(protectedTotal))")
            fflush(stdout)
            finished.signal()
        }
        finished.wait()
    }

    private static func storedAreas(_ key: String) -> Set<Area> {
        Set((UserDefaults.standard.stringArray(forKey: key) ?? []).compactMap(Area.init(rawValue:)))
    }

    /// Prints what decides the developer areas: the tools found, the kinds of project in the project
    /// folders, and the variables the login shell sets that say where a tool keeps its folders.
    static func printStack() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let roots = AppSettings().scanContext().projectRoots
        let asked = Set(Catalog.allGroups.flatMap(\.locations).flatMap(\.asks).compactMap { ask -> String? in
            if case .variable(let name, _) = ask { name } else { nil }
        }).union(["XDG_CACHE_HOME"])

        let finished = DispatchSemaphore(value: 0)
        Task.detached {
            let kinds = await StackDetector.projectKinds(in: roots, home: home)
            let stack = StackDetector.detect(home: home).adding(kinds, hasProjectFolders: !roots.isEmpty)
            for area in Area.allCases where area.isDeveloper {
                let found = stack.applies(area) ? (stack.found[area] ?? []).joined(separator: ", ") : "not found"
                print("\(area.title.padding(toLength: 24, withPad: " ", startingAt: 0)) \(found)")
            }
            let environment = await ShellEnvironment.load()
            print("\nLogin shell: \(environment.variables.count) variables, \(environment.searchDirectories.count) folders on the PATH")
            for name in asked.sorted() {
                if let folder = environment.folder(named: name) { print("   \(name) = \(folder.path)") }
            }
            fflush(stdout)
            finished.signal()
        }
        finished.wait()
    }

    /// The Quick Clean path without the window: the same scan, the same Safe-only selection, the same
    /// guard, in-use and freshness checks, the same log. Only the confirmation click is missing,
    /// which is why this exists for the terminal alone.
    static func quickClean() {
        let settings = AppSettings()
        let home = FileManager.default.homeDirectoryForCurrentUser
        var context = settings.scanContext()
        context.shell = ShellEnvironment.loading()
        let safety = SafetyGuard(
            root: home,
            extraRoots: GuardRoots.userTemporaryFolders(),
            allowedApplications: settings.offersOldXcodes ? GuardRoots.otherXcodes() : [],
            neverSuggest: settings.neverSuggest.map(\.path),
            backupsAllowed: true
        )
        let disabled = storedAreas("disabledAreas")
        let forced = storedAreas("forcedAreas")
        let roots = context.projectRoots

        let finished = DispatchSemaphore(value: 0)
        Task.detached {
            let stack = StackDetector.detect(home: home)
                .adding(await StackDetector.projectKinds(in: roots, home: home), hasProjectFolders: !roots.isEmpty)
            let areas = Area.allCases.filter { stack.scans($0, disabled: disabled, forced: forced) }
            print("Scanning \(areas.count) areas")
            var findings: [Finding] = []
            for await event in ScanEngine.events(areas: areas, context: context) {
                if case .finished(let area, let result) = event {
                    findings += result.findings
                    print("   \(area.title): \(ByteFormat.string(result.findings.reduce(0) { $0 + $1.size }))"
                          + (result.skipReason.map { "  (\($0))" } ?? ""))
                }
            }
            let scannedAt = Date()
            findings.sort { ($0.tier, -$0.size) < ($1.tier, -$1.size) }
            let selection = Set(findings.filter { $0.tier == .safe }.flatMap { finding in
                finding.items.filter { $0.preselected ?? true }.map(\.id)
            })
            let plan = CleanPlan.make(findings: findings, selection: selection)
            var skipping: [String: String] = [:]
            for step in plan.steps {
                if let check = step.waitsFor, InUse.isActive(check) { skipping[step.id] = check.skipReason }
            }

            print("\nPlan: Safe tier only, \(plan.steps.count) groups, \(ByteFormat.string(plan.totalSize))")
            for step in plan.steps {
                let state = skipping[step.id].map { _ in "WAITS " } ?? "clean "
                print("   \(state)\(ByteFormat.string(step.size).padding(toLength: 9, withPad: " ", startingAt: 0)) \(step.title)  |  \(step.summary)")
            }
            guard !plan.isEmpty else {
                print("\nNothing safe to remove.")
                fflush(stdout)
                finished.signal()
                return
            }

            print("\nCleaning")
            let outcome = await Cleaner.run(plan: plan, safety: safety, skipping: skipping, scannedAt: scannedAt) { _ in }
            print("\nReceipt")
            for step in outcome.steps {
                let mark = step.skippedReason != nil ? "-" : step.failures.isEmpty && step.skippedItems.isEmpty ? "ok" : "!"
                print("   \(mark.padding(toLength: 3, withPad: " ", startingAt: 0))\(ByteFormat.string(step.size).padding(toLength: 9, withPad: " ", startingAt: 0)) \(step.title)")
                if let reason = step.skippedReason { print("      \(reason)") }
                for (_, reason) in step.skippedItems { print("      skipped: \(reason)") }
                for failure in step.failures { print("      failed: \(failure)") }
            }
            print("\nFree space: \(ByteFormat.string(outcome.freeBefore)) before, \(ByteFormat.string(outcome.freeAfter)) after, "
                  + "\(ByteFormat.string(outcome.reclaimed)) reclaimed in \(String(format: "%.0f", outcome.duration)) s")
            if let log = outcome.logURL { print("Log: \(log.path)") }
            fflush(stdout)
            finished.signal()
        }
        finished.wait()
    }

    /// Prints what the Applications scan finds. Nothing is removed.
    static func printApps(matching name: String?, updates: Bool) {
        let settings = AppSettings()
        let home = FileManager.default.homeDirectoryForCurrentUser
        let safety = SafetyGuard(root: home, neverSuggest: settings.neverSuggest.map(\.path))
        let region = Locale.current.region?.identifier ?? AppUpdateChecker.fallbackRegion
        let finished = DispatchSemaphore(value: 0)
        Task.detached {
            let started = Date()
            let apps = await AppScanner.scan(home: home, safety: safety) { _ in }
            let seconds = String(format: "%.1f", Date().timeIntervalSince(started))
            let unused = apps.count { $0.isUnused() }
            let store = apps.count { $0.source == .appStore }
            print("\(apps.count) apps in \(seconds) s: \(ByteFormat.string(apps.reduce(0) { $0 + $1.size })), "
                  + "\(unused) unused, \(store) from the App Store, \(apps.count { $0.needsPassword }) that only Finder can move")
            let shown = apps.filter { app in name.map { app.name.localizedStandardContains($0) } ?? true }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            for app in shown {
                let opened = app.lastOpened.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "never"
                let flags = [app.source == .appStore ? "App Store" : nil, app.needsPassword ? "Finder only" : nil,
                             app.isUnused() ? "unused" : nil, app.feed.map { _ in "has a feed" }].compactMap { $0 }
                print("\n\(app.name)  \(app.version)  \(app.bundleID)  \(ByteFormat.string(app.size))  opened \(opened)"
                      + (flags.isEmpty ? "" : "  [\(flags.joined(separator: ", "))]"))
                guard name != nil else { continue }
                for kind in app.kinds {
                    print("   \(kind.title)")
                    for file in app.files(of: kind) {
                        let size = file.sizeUnknown ? "unknown" : ByteFormat.string(file.size)
                        print("      \(size.padding(toLength: 9, withPad: " ", startingAt: 0)) \(file.url.path)")
                    }
                }
            }
            if updates {
                let newer = await AppUpdateChecker.updates(for: apps, region: region)
                print("\n\(newer.count) updates")
                for update in newer {
                    let app = apps.first { $0.id == update.id }?.name ?? update.id
                    let released = update.released.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "unknown date"
                    print("   \(app): \(update.installedVersion) -> \(update.newVersion)  (\(update.feed.title), \(released)"
                          + (update.size.map { ", \(ByteFormat.string($0))" } ?? "") + ")")
                }
            }
            fflush(stdout)
            finished.signal()
        }
        finished.wait()
    }

    /// The Uninstall button's path for one app, without the window. Only the confirmation click is missing,
    /// which is why this exists for the terminal alone.
    static func uninstall(appAt path: String) {
        let settings = AppSettings()
        let home = FileManager.default.homeDirectoryForCurrentUser
        let neverSuggest = settings.neverSuggest.map(\.path)
        let scanSafety = SafetyGuard(root: home, neverSuggest: neverSuggest)
        let target = URL(fileURLWithPath: path).standardizedFileURL.path
        let finished = DispatchSemaphore(value: 0)
        Task.detached {
            defer {
                fflush(stdout)
                finished.signal()
            }
            let apps = await AppScanner.scan(home: home, safety: scanSafety) { _ in }
            guard let app = apps.first(where: { $0.url.standardizedFileURL.path == target }) else {
                print("No app at \(path) in the Applications folders.")
                return
            }
            if RunningApps.isRunning(bundleID: app.bundleID) {
                print("\(app.name) is open, so it was left alone.")
                return
            }
            let selection = Set(app.files.map(\.id))
            let plan = Uninstaller.plan(for: [app], selection: selection)
            for step in plan.steps {
                print("\(step.title): \(step.summary), \(ByteFormat.string(step.size))")
                for operation in step.operations {
                    if case .trash(let url) = operation.kind { print("   \(url.path)") }
                }
            }
            let safety = SafetyGuard(root: home, allowedApplications: Uninstaller.bundles(in: [app], selection: selection),
                                     neverSuggest: neverSuggest)
            let outcome = await Cleaner.run(plan: plan, safety: safety) { _ in }
            PutBack.save(outcome, home: home)
            for step in outcome.steps {
                print(step.failures.isEmpty ? "ok   \(step.cleanedItemIDs.count) items moved to the Trash" : "!    \(step.failures.joined(separator: "; "))")
            }
            if let log = outcome.logURL { print("Log: \(log.path)") }
        }
        finished.wait()
    }

    static func printSpace(folder: String) {
        let started = Date()
        var items = 0
        let root = SpaceScanner.measure(
            root: URL(fileURLWithPath: folder, isDirectory: true),
            threshold: SpaceScanner.listingThreshold
        ) { items = $0.items }
        guard let root else {
            print("Could not read \(folder)")
            return
        }
        let seconds = String(format: "%.1f", Date().timeIntervalSince(started))
        print("\(root.path): \(ByteFormat.string(root.size)), \(items) items in \(seconds) s\(root.isIncomplete ? " (incomplete)" : "")")
        for child in root.children.prefix(12) {
            print("  \(line(for: child))")
            for grandchild in child.children.prefix(3) {
                print("      \(line(for: grandchild))")
            }
        }
        print("  \(ByteFormat.string(root.smallerItemsSize).padding(toLength: 9, withPad: " ", startingAt: 0)) (smaller items)")
        fflush(stdout)
    }

    private static func line(for node: SpaceNode) -> String {
        let size = node.isUnreadable ? "unknown" : ByteFormat.string(node.size)
        let flag = node.isUnreadable ? "  [unreadable]" : node.isIncomplete ? "  [incomplete]" : ""
        return "\(size.padding(toLength: 9, withPad: " ", startingAt: 0)) \(node.name)\(node.isDirectory ? "/" : "")\(flag)"
    }
}
#endif
