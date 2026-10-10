//
//  AppsModel.swift
//  SwiftMacCleaner
//

import AppKit
import Observation
import SwiftUI

/// State behind the Applications screen: the installed apps, which of them have an update, what removed
/// apps left behind, and whatever the user has ticked for removal.
@Observable
final class AppsModel {
    enum Phase {
        case idle, scanning, summary, managing, removing, done
    }

    /// The three parts of the manager.
    enum Section: String, CaseIterable, Identifiable {
        case uninstaller, updater, leftovers

        var id: String { rawValue }
        var title: String {
            switch self {
            case .uninstaller: "Uninstaller"
            case .updater: "Updater"
            case .leftovers: "Leftovers"
            }
        }
        var detail: String {
            switch self {
            case .uninstaller: "Remove whole apps together with the files they keep in your Library."
            case .updater: "See which apps have a newer version. Homebrew installs the ones it manages; the rest are updated where they came from."
            case .leftovers: "Files left by apps that are already gone, and installers you no longer need."
            }
        }
    }

    /// Which apps the uninstaller lists.
    enum Filter: Hashable {
        case all, unused, selected
        case source(AppSource)
        case vendor(AppVendor)

        var title: String {
            switch self {
            case .all: "All Applications"
            case .unused: "Unused"
            case .selected: "Selected"
            case .source(let source): source.title
            case .vendor(let vendor): vendor.title
            }
        }
    }

    enum Sort: String, CaseIterable, Identifiable {
        case name, size, lastOpened

        var id: String { rawValue }
        var title: String {
            switch self {
            case .name: "Name"
            case .size: "Size"
            case .lastOpened: "Last Opened"
            }
        }
    }

    /// What a removal took away, which decides how the result is worded.
    struct Removal {
        var isUninstall: Bool
        var apps: Int
        var items: Int
        var size: Int64
    }

    static let installersFindingID = "installers.downloads"
    static let leftoverFilesFindingID = "leftovers.apps"

    let home: URL
    let settings: AppSettings
    /// Called after a removal, so the owner can refresh the disk figure and the offer to put things back.
    @ObservationIgnored var didRemove: (CleanOutcome) -> Void = { _ in }
    /// Called when a scan ends or is stopped, so the overview knows when every part of its scan is done.
    @ObservationIgnored var didScan: () -> Void = {}

    private(set) var phase: Phase = .idle
    private(set) var progress = AppScanProgress()
    private(set) var apps: [InstalledApp] = []
    private(set) var updates: [AppUpdate] = []
    /// False when the update feeds were not asked, because the setting is off.
    private(set) var checkedUpdates = false
    /// Installers and leftover files, the two areas that are Applications' own.
    private(set) var leftovers: [Finding] = []
    /// Folders macOS would not let the scan read.
    private(set) var unreadable: [String] = []
    private(set) var selectedFiles: Set<String> = []
    private(set) var selectedLeftovers: Set<String> = []
    /// Bundle identifiers of listed apps that are open. Looked up after a scan and before a removal, not per row.
    private(set) var running: Set<String> = []
    private(set) var removeProgress = CleanProgress(fraction: 0, status: "")
    private(set) var outcome: CleanOutcome?
    private(set) var removal = Removal(isUninstall: true, apps: 0, items: 0, size: 0)
    /// What the receipt says under a step whose app had files under /Library, by step.
    private(set) var receiptDetails: [String: String] = [:]
    /// Updates Homebrew is installing or has yet to get to, by app. It works on one at a time.
    private(set) var installing: Set<String> = []
    /// The one it is working on right now.
    private(set) var installingNow: String?
    /// Why an update did not go through, by app, for the line under its row.
    private(set) var installFailures: [String: String] = [:]

    var section: Section = .uninstaller
    var filter: Filter = .all
    var sort: Sort = .name
    var search = ""
    /// Apps whose files are listed under them.
    var expanded: Set<String> = []
    var showingReview = false

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var scanned: Date?
    @ObservationIgnored private var installTask: Task<Void, Never>?
    /// Has Homebrew upgrade one cask. Nil when Homebrew is not installed, so nothing is offered through it.
    @ObservationIgnored var upgradeCask: (@Sendable (String) async -> HomebrewCasks.UpgradeResult)? = AppsModel.homebrewUpgrade()
    @ObservationIgnored var isAppRunning: (String) -> Bool = RunningApps.isRunning(bundleID:)

    init(home: URL, settings: AppSettings) {
        self.home = home
        self.settings = settings
    }

    // MARK: Scanning

    func startScan() {
        // Homebrew is half-way through replacing an app. The list is looked at again when it is done.
        guard installing.isEmpty else { return didScan() }
        task?.cancel()
        installFailures = [:]
        apps = []
        updates = []
        leftovers = []
        unreadable = []
        selectedFiles = []
        selectedLeftovers = []
        expanded = []
        outcome = nil
        search = ""
        filter = .all
        showingReview = false
        progress = AppScanProgress()
        phase = .scanning

        let safety = SafetyGuard(root: home, neverSuggest: settings.neverSuggest.map(\.path))
        let context = settings.scanContext(home: home)
        let checksUpdates = settings.checksAppUpdates
        let region = Locale.current.region?.identifier ?? AppUpdateChecker.fallbackRegion
        task = Task { [home] in
            async let leftoverFiles = ScanEngine.scan(.leftovers, context: context)
            async let installers = ScanEngine.scan(.installers, context: context)
            let found = await AppScanner.scan(home: home, safety: safety) { progress in
                Task { @MainActor in
                    if self.phase == .scanning { self.progress = progress }
                }
            }
            var newer: [AppUpdate] = []
            if checksUpdates, !Task.isCancelled {
                progress = AppScanProgress(done: found.count, total: found.count, isCheckingUpdates: true)
                newer = await AppUpdateChecker.updates(for: found, region: region)
            }
            let results = await [installers, leftoverFiles]
            guard !Task.isCancelled else { return }
            apps = found
            updates = newer
            checkedUpdates = checksUpdates
            leftovers = results.flatMap(\.findings)
            unreadable = results.flatMap(\.unreadable)
            scanned = Date()
            refreshRunning()
            phase = .summary
            didScan()
        }
    }

    func stop() {
        task?.cancel()
        phase = .idle
        didScan()
    }

    /// Forgets the scan and goes back to the opening screen.
    func reset() {
        task?.cancel()
        showingReview = false
        phase = .idle
    }

    // MARK: Navigation

    /// Opens the manager on one of its parts.
    func manage(_ section: Section, filter: Filter = .all) {
        self.section = section
        self.filter = filter
        search = ""
        refreshRunning()
        phase = .managing
    }

    func showSummary() {
        guard phase == .managing || phase == .done else { return }
        phase = .summary
    }

    // MARK: Apps

    var unusedApps: [InstalledApp] { apps.filter { $0.isUnused() } }

    /// The stores and makers that have at least one app here, which are the only ones worth a filter.
    var sources: [AppSource] { AppSource.allCases.filter { source in apps.contains { $0.source == source } } }
    var vendors: [AppVendor] {
        let present = AppVendor.allCases.filter { vendor in apps.contains { $0.vendor == vendor } }
        return present == [.other] ? [] : present
    }

    func matches(_ app: InstalledApp, _ filter: Filter) -> Bool {
        switch filter {
        case .all: true
        case .unused: app.isUnused()
        case .selected: app.files.contains { selectedFiles.contains($0.id) }
        case .source(let source): app.source == source
        case .vendor(let vendor): app.vendor == vendor
        }
    }

    func count(for filter: Filter) -> Int { apps.count { matches($0, filter) } }

    /// The apps the uninstaller shows: the chosen filter, narrowed by the search, in the chosen order.
    var visibleApps: [InstalledApp] {
        let query = search.trimmingCharacters(in: .whitespaces)
        let shown = apps.filter { app in
            matches(app, filter) && (query.isEmpty || app.name.localizedStandardContains(query)
                                     || app.bundleID.localizedStandardContains(query))
        }
        return switch sort {
        case .name: shown.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .size: shown.sorted { $0.size > $1.size }
        // The longest unopened first, which is what someone looking for apps to remove wants at the top.
        case .lastOpened: shown.sorted { ($0.lastOpened ?? $0.installed ?? .distantPast) < ($1.lastOpened ?? $1.installed ?? .distantPast) }
        }
    }

    func app(withID id: String) -> InstalledApp? { apps.first { $0.id == id } }
    func update(for app: InstalledApp) -> AppUpdate? { updates.first { $0.id == app.id } }

    func isExpanded(_ app: InstalledApp) -> Bool { expanded.contains(app.id) }

    func toggleExpanded(_ app: InstalledApp) {
        if expanded.contains(app.id) { expanded.remove(app.id) } else { expanded.insert(app.id) }
    }

    // MARK: Running apps

    func isRunning(_ app: InstalledApp) -> Bool { running.contains(app.bundleID) }

    func refreshRunning() {
        running = Set(apps.map(\.bundleID).filter(RunningApps.isRunning))
    }

    /// Asks the app to quit, the way its own Quit command would, so it can still ask about unsaved work.
    func quit(_ app: InstalledApp) {
        for instance in NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID) {
            instance.terminate()
        }
        Task {
            // Quitting takes a moment, and longer when the app stops to ask something.
            for _ in 0..<40 where running.contains(app.bundleID) {
                try? await Task.sleep(for: .milliseconds(250))
                refreshRunning()
            }
        }
    }

    // MARK: Selection

    func binding(for file: AppFile) -> Binding<Bool> {
        Binding(
            get: { self.selectedFiles.contains(file.id) },
            set: { isOn in
                if isOn { self.selectedFiles.insert(file.id) } else { self.selectedFiles.remove(file.id) }
            }
        )
    }

    /// One binding per file, for a tick box that shows a dash when only some are ticked.
    func bindings(for files: [AppFile]) -> [Binding<Bool>] { files.map(binding(for:)) }

    func selectedSize(in app: InstalledApp) -> Int64 {
        app.files.reduce(0) { $0 + (selectedFiles.contains($1.id) ? $1.size : 0) }
    }

    var selectedAppSize: Int64 { apps.reduce(0) { $0 + selectedSize(in: $1) } }

    /// Apps whose bundle is ticked, which are the ones that will be gone.
    var selectedAppCount: Int {
        apps.count { app in app.bundleFile.map { selectedFiles.contains($0.id) } == true }
    }

    func selectAllVisible() {
        selectedFiles.formUnion(visibleApps.flatMap(\.files).map(\.id))
    }

    func selectNone() {
        switch section {
        case .leftovers: selectedLeftovers = []
        case .uninstaller, .updater: selectedFiles = []
        }
    }

    // MARK: Leftovers

    func finding(withID id: String) -> Finding? { leftovers.first { $0.id == id } }

    var installerSize: Int64 { finding(withID: Self.installersFindingID)?.size ?? 0 }
    var leftoverFileSize: Int64 { finding(withID: Self.leftoverFilesFindingID)?.size ?? 0 }

    func binding(for item: FindingItem) -> Binding<Bool> {
        Binding(
            get: { self.selectedLeftovers.contains(item.id) },
            set: { isOn in
                if isOn { self.selectedLeftovers.insert(item.id) } else { self.selectedLeftovers.remove(item.id) }
            }
        )
    }

    func bindings(for finding: Finding) -> [Binding<Bool>] { finding.items.map(binding(for:)) }

    var selectedLeftoverSize: Int64 {
        leftovers.flatMap(\.items).reduce(0) { $0 + (selectedLeftovers.contains($1.id) ? $1.size : 0) }
    }

    var selectedLeftoverCount: Int { selectedLeftovers.count }

    // MARK: Updates

    func open(_ update: AppUpdate) {
        if update.feed == .appStore, let page = update.storeURL {
            NSWorkspace.shared.open(page)
        } else if let app = app(withID: update.id) {
            NSWorkspace.shared.openApplication(at: app.url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    func openAppStoreUpdates() {
        if let url = URL(string: "macappstore://showUpdatesPage") { NSWorkspace.shared.open(url) }
    }

    // MARK: Installing with Homebrew

    /// The real thing: `brew upgrade` for one cask, run off the main thread and waited for.
    static func homebrewUpgrade() -> (@Sendable (String) async -> HomebrewCasks.UpgradeResult)? {
        guard let brew = HomebrewCasks.brew() else { return nil }
        return { token in
            await Task.detached { HomebrewCasks.upgrade(token: token, brew: brew) }.value
        }
    }

    /// Whether this app can install the update itself: Homebrew installed the app, and Homebrew is there.
    func canInstall(_ update: AppUpdate) -> Bool { update.cask != nil && upgradeCask != nil }

    var installableUpdates: [AppUpdate] { updates.filter(canInstall) }

    /// Has Homebrew install the updates, one after another: it will not work on two things at once.
    func install(_ chosen: [AppUpdate]) {
        let fresh = chosen.filter { canInstall($0) && !installing.contains($0.id) }
        guard !fresh.isEmpty else { return }
        installing.formUnion(fresh.map(\.id))
        for update in fresh { installFailures[update.id] = nil }
        let earlier = installTask
        installTask = Task {
            await earlier?.value
            for update in fresh {
                installingNow = update.id
                if let failure = await install(update) { installFailures[update.id] = failure }
                installing.remove(update.id)
            }
            installingNow = nil
        }
    }

    /// Installs one update and takes it off the list. Returns the sentence to show when it did not go through.
    private func install(_ update: AppUpdate) async -> String? {
        guard let app = app(withID: update.id), let token = update.cask, let upgradeCask else { return nil }
        // Nothing is quit for the user, and an app is not replaced while it runs.
        guard !isAppRunning(app.bundleID) else {
            refreshRunning()
            return "\(app.name) is open. Quit it, then update again."
        }
        if case .failed(let reason) = await upgradeCask(token) { return reason }

        // The app is read again: what counts is the version that is there now, not what Homebrew said.
        guard let index = apps.firstIndex(where: { $0.id == update.id }) else { return nil }
        if let fresh = AppScanner.describe(app.url)?.app {
            apps[index].version = fresh.version
            apps[index].build = fresh.build
            apps[index].installed = fresh.installed
            if AppUpdateChecker.isNewer(update.newVersion, than: fresh.version) {
                return "Homebrew finished, but \(app.name) is still version \(fresh.version)."
            }
            let size = await Sizing.sizes(of: [app.url])[app.url]
            if let size, let bundle = apps.firstIndex(where: { $0.id == update.id }),
               let file = apps[bundle].files.firstIndex(where: { $0.kind == .binaries }) {
                apps[bundle].files[file].size = size
            }
        }
        updates.removeAll { $0.id == update.id }
        return nil
    }

    // MARK: Removing

    /// Whether the round button removes leftovers or uninstalls apps.
    var removesLeftovers: Bool { section == .leftovers }

    var plan: CleanPlan {
        removesLeftovers
            ? CleanPlan.make(findings: leftovers, selection: selectedLeftovers)
            : Uninstaller.plan(for: apps, selection: selectedFiles, home: home)
    }

    /// The apps the plan touches, in the order of its steps.
    func apps(in plan: CleanPlan) -> [InstalledApp] {
        let ids = Set(plan.steps.map(\.id))
        return apps.filter { ids.contains(Uninstaller.stepID(for: $0)) }
    }

    /// Steps that have to wait because their app is open, with the sentence for the receipt.
    func blockedSteps(in plan: CleanPlan) -> [String: String] {
        guard !removesLeftovers else { return [:] }
        var blocked: [String: String] = [:]
        for app in apps(in: plan) where running.contains(app.bundleID) {
            blocked[Uninstaller.stepID(for: app)] = "\(app.name) was open, so it was left alone. Quit it and uninstall again."
        }
        return blocked
    }

    var needsPassword: Bool { !removesLeftovers && Uninstaller.needsPassword(apps, selection: selectedFiles) }
    /// Whether an app that belongs to root is ticked, which Finder is asked to move.
    var needsFinder: Bool { !removesLeftovers && Uninstaller.needsFinder(apps, selection: selectedFiles) }

    /// The ticked files that sit under /Library, which are moved with the password and cannot be put back.
    func selectedSystemFiles(of app: InstalledApp) -> [AppFile] { Uninstaller.systemFiles(of: app, in: selectedFiles) }

    /// How many of those a removal would move right now: an app that is open is left alone, its files too.
    var selectedSystemFileCount: Int {
        guard !removesLeftovers else { return 0 }
        return apps.reduce(0) { $0 + (running.contains($1.bundleID) ? 0 : selectedSystemFiles(of: $1).count) }
    }

    func receiptDetail(for step: StepOutcome) -> String? { receiptDetails[step.id] }

    func remove() {
        let plan = plan
        guard !plan.isEmpty, phase == .managing else { return }
        refreshRunning()
        let isUninstall = !removesLeftovers
        let skipping = blockedSteps(in: plan)
        let safety = SafetyGuard(
            root: home,
            allowedApplications: isUninstall ? Uninstaller.bundles(in: apps, selection: selectedFiles) : [],
            neverSuggest: settings.neverSuggest.map(\.path)
        )
        // An app's own files change all the time, so only leftovers are checked for changes since the scan.
        let scannedAt = isUninstall ? nil : scanned
        showingReview = false
        removeProgress = CleanProgress(fraction: 0, status: "Getting ready")
        phase = .removing
        Task {
            let result = await Cleaner.run(plan: plan, safety: safety, skipping: skipping, scannedAt: scannedAt) { progress in
                Task { @MainActor in self.removeProgress = progress }
            }
            finish(result, isUninstall: isUninstall)
        }
    }

    private func finish(_ result: CleanOutcome, isUninstall: Bool) {
        let removed = isUninstall ? Uninstaller.removedFiles(in: result, apps: apps, selection: selectedFiles) : result.cleanedItemIDs
        receiptDetails = [:]
        if isUninstall {
            for step in result.steps {
                guard let app = apps.first(where: { Uninstaller.stepID(for: $0) == step.id }) else { continue }
                receiptDetails[step.id] = Uninstaller.receiptDetail(for: app, step: step, selection: selectedFiles, removed: removed)
            }
        }
        let before = apps.count
        let size = apps.flatMap(\.files).filter { removed.contains($0.id) }.reduce(0) { $0 + $1.size }
            + leftovers.flatMap(\.items).filter { removed.contains($0.id) }.reduce(0) { $0 + $1.size }
        // An app whose bundle is gone leaves the list. Files of it that were not ticked show up as leftovers next time.
        apps = apps.compactMap { app in
            var app = app
            app.files.removeAll { removed.contains($0.id) }
            return app.bundleFile == nil ? nil : app
        }
        let remaining = Set(apps.map(\.id))
        updates.removeAll { !remaining.contains($0.id) }
        expanded.formIntersection(remaining)
        leftovers = leftovers.compactMap { finding in
            var finding = finding
            finding.items.removeAll { removed.contains($0.id) }
            return finding.items.isEmpty ? nil : finding
        }
        selectedFiles.subtract(removed)
        selectedLeftovers.subtract(removed)
        removal = Removal(isUninstall: isUninstall, apps: before - apps.count, items: removed.count, size: size)
        outcome = result
        refreshRunning()
        didRemove(result)
        phase = .done
    }

    /// Back to the manager after a removal, for whatever else is on the list.
    func manageMore() {
        guard phase == .done else { return }
        phase = apps.isEmpty && leftovers.isEmpty ? .summary : .managing
    }

    func showInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// The path with the home folder written as `~`.
    func displayPath(_ url: URL) -> String {
        let path = url.path
        let homePath = home.path
        guard path == homePath || path.hasPrefix(homePath + "/") else { return path }
        return "~" + path.dropFirst(homePath.count)
    }

    #if DEBUG
    /// Fills the screen with made-up apps and opens the named part of it. See `AppsDemoData`.
    func showDemo(_ screen: String) {
        // `scan` is the one screen that is not made up: it looks at the real apps, which only reads.
        if screen == "scan" {
            startScan()
            return
        }
        apps = AppsDemoData.apps()
        updates = AppsDemoData.updates(for: apps)
        checkedUpdates = true
        // Made-up apps are never handed to the real Homebrew.
        upgradeCask = { _ in
            try? await Task.sleep(for: .seconds(2))
            return .done
        }
        isAppRunning = { _ in false }
        leftovers = AppsDemoData.leftovers()
        running = ["com.example.harbor"]
        scanned = Date()
        phase = .managing
        switch screen {
        case "intro":
            phase = .idle
        case "scanning":
            progress = AppScanProgress(done: 17, total: 43, name: "Harbor")
            phase = .scanning
        case "summary":
            phase = .summary
        case "updater":
            section = .updater
        case "updater-homebrew":
            // Two for Homebrew, one of which it cannot install: the queue, and what a failure says.
            section = .updater
            for index in updates.indices where app(withID: updates[index].id)?.name == "Inkwell" { updates[index].cask = "inkwell" }
            upgradeCask = { token in
                try? await Task.sleep(for: .seconds(2))
                let refused = Shell.Output(status: 1, stdout: "", stderr: "sudo: a terminal is required to read the password", timedOut: false, cancelled: false)
                return token == "inkwell" ? .done : .failed(HomebrewCasks.failure(from: refused, token: token))
            }
        case "leftovers":
            section = .leftovers
            selectedLeftovers = Set(leftovers.first?.items.prefix(2).map(\.id) ?? [])
        case "review", "removing", "done":
            let chosen = apps.filter { ["Harbor", "Keyframe", "Tally"].contains($0.name) }
            selectedFiles = Set(chosen.flatMap(\.files).map(\.id))
            expanded = Set(chosen.prefix(1).map(\.id))
            if screen == "review" {
                showingReview = true
            } else if screen == "removing" {
                removeProgress = CleanProgress(fraction: 0.4, status: "Keyframe")
                phase = .removing
            } else {
                let result = AppsDemoData.outcome(for: plan, blocked: blockedSteps(in: plan))
                finish(result, isUninstall: true)
            }
        default:
            expanded = Set(apps.prefix(1).map(\.id))
            selectedFiles = Set(apps.prefix(1).flatMap(\.files).map(\.id))
        }
    }
    #endif
}
