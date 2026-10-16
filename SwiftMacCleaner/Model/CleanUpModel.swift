//
//  CleanUpModel.swift
//  SwiftMacCleaner
//

import AppKit
import Observation
import SwiftUI

/// One clean-up from start to finish: a scan over its group's areas, what it found, what is ticked, the
/// confirmation, the clean and its receipt. System Clean Up, Developer Clean Up and Large old files
/// are one each; the overview runs them all together and reads their results.
@Observable
final class CleanUpModel {
    enum Phase {
        case home, scanning, results, cleaning, done
    }

    enum AreaState: Equatable {
        case idle, queued, scanning, finished
        case skipped(String)
    }

    let home: URL
    let settings: AppSettings
    /// Which apps are open, for the items that wait on one.
    let openApps: OpenApps
    /// Which clean-up this is.
    let group: AreaGroup
    /// The areas this clean-up may look at, in the order they are listed.
    var areas: [Area] { group.areas }
    /// Called when a scan ends, so the owner can note the time and refresh the disk figure.
    @ObservationIgnored var didScan: () -> Void = {}
    /// Called after a clean, so the owner can refresh the disk figure and the offer to put things back.
    @ObservationIgnored var didClean: (CleanOutcome) -> Void = { _ in }
    /// Called after a clean with what it did, for My Activity.
    @ObservationIgnored var didRecord: (ActivityRecord) -> Void = { _ in }

    private(set) var phase: Phase = .home
    private(set) var areaStates: [Area: AreaState] = [:]
    private(set) var findings: [Finding] = []
    /// What the scan found and deliberately left alone.
    private(set) var protected: [ProtectedItem] = []
    private(set) var selection: Set<String> = []
    /// Folders macOS would not let the last scan read.
    private(set) var unreadableFolders: [String] = []
    private(set) var scanDuration: TimeInterval = 0
    private(set) var scanFinished: Date?
    private(set) var cleanProgress = CleanProgress(fraction: 0, status: "")
    private(set) var outcome: CleanOutcome?
    /// Findings whose in-use check was active the last time it was looked at, for the badges on rows.
    /// Asking costs a process launch, so it happens after a scan and on the background tick, not per render.
    private(set) var activeChecksByFinding: [String: InUseCheck] = [:]
    /// The one area the confirmation covers, or nil for everything that is ticked.
    private(set) var reviewArea: Area?

    /// The area open in the manager, for a clean-up with pages of its own. Nil is its summary.
    /// The overview does not use it: there the sidebar selection says which page is on screen.
    var openArea: Area?
    var showingReview = false

    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var scanStarted = Date()
    /// Set by Scan and Clean: open the confirmation as soon as the scan ends, with the Smart selection ticked.
    @ObservationIgnored private var reviewWhenScanned = false

    init(home: URL, settings: AppSettings, group: AreaGroup, openApps: OpenApps = OpenApps()) {
        self.home = home
        self.settings = settings
        self.group = group
        self.openApps = openApps
    }

    /// Whether a scan is under way or a clean, during which the overview counts this clean-up as busy.
    var isBusy: Bool { phase == .scanning || phase == .cleaning }

    // MARK: Scanning

    /// Scans the given areas, or every area of this clean-up. With `thenReview`, the confirmation
    /// opens on its own when the scan ends, over the Smart selection the scan ticked.
    func startScan(areas requested: [Area]? = nil, thenReview: Bool = false) {
        let scanned = requested ?? areas
        guard !scanned.isEmpty else { return }
        scanTask?.cancel()
        reviewWhenScanned = thenReview

        findings = []
        protected = []
        selection = []
        outcome = nil
        unreadableFolders = []
        areaStates = Dictionary(uniqueKeysWithValues: areas.map { ($0, scanned.contains($0) ? .queued : .idle) })
        openArea = nil
        reviewArea = nil
        showingReview = false
        phase = .scanning
        scanStarted = Date()

        var context = settings.scanContext(home: home)
        // Only developer tools are asked where they keep things, so only their areas need the shell.
        if scanned.contains(where: \.isDeveloper) { context.shell = ShellEnvironment.loading() }
        if !settings.offersSnapshots { context.excluded.append(SnapshotScanner.snapshotsItemID) }
        if !settings.offersOldXcodes { context.excluded.append(XcodeScanner.oldXcodesFindingID) }
        scanTask = Task {
            for await event in ScanEngine.events(areas: scanned, context: context) {
                apply(event)
            }
            guard !Task.isCancelled else { return }
            finishScan()
        }
    }

    /// Stops early and shows whatever has been found so far.
    func stopScan() {
        guard phase == .scanning else { return }
        scanTask?.cancel()
        for (area, state) in areaStates where state == .queued || state == .scanning {
            areaStates[area] = .skipped("The scan was stopped before this area finished.")
        }
        finishScan()
    }

    /// Forgets the scan and goes back to the opening screen.
    func reset() {
        scanTask?.cancel()
        findings = []
        protected = []
        selection = []
        areaStates = [:]
        openArea = nil
        showingReview = false
        phase = .home
    }

    private func apply(_ event: ScanEvent) {
        switch event {
        case .started(let area):
            areaStates[area] = .scanning
        case .finished(let area, let result):
            findings.append(contentsOf: result.findings)
            protected.append(contentsOf: result.protected)
            unreadableFolders += result.unreadable
            areaStates[area] = result.skipReason.map(AreaState.skipped) ?? .finished
        }
    }

    private func finishScan() {
        findings.sort { ($0.aftermath, -$0.size) < ($1.aftermath, -$1.size) }
        protected.sort { ($0.size ?? -1) > ($1.size ?? -1) }
        selection = smartSelection
        scanDuration = Date().timeIntervalSince(scanStarted)
        scanFinished = Date()
        refreshActiveChecks()
        phase = findings.isEmpty && areaStates.values.allSatisfy({ $0 == .idle }) ? .home : .results
        didScan()
        if reviewWhenScanned {
            reviewWhenScanned = false
            reviewSmart()
        }
    }

    #if DEBUG
    /// Shows the given findings as if a scan had just finished. For demo mode and tests.
    func show(findings newFindings: [Finding], protected newProtected: [ProtectedItem] = []) {
        findings = newFindings
        protected = newProtected
        areaStates = Dictionary(uniqueKeysWithValues: areas.map { ($0, .finished) })
        finishScan()
        phase = .results
    }

    /// Shows the given receipt as if a clean had just finished. For demo mode: nothing is saved for Put Back.
    func show(outcome result: CleanOutcome) {
        take(result)
    }

    /// Marks an area as skipped, for a demo of the "nothing to clean" panel.
    func markSkipped(_ area: Area, reason: String) {
        areaStates[area] = .skipped(reason)
    }

    /// Fills the clean-up with made-up results for its areas and opens the named screen. See `DemoData`.
    func showDemo(_ screen: String) {
        if screen == "scan" {
            startScan()
            return
        }
        let scope = Set(areas)
        show(findings: DemoData.findings().filter { scope.contains($0.area) },
             protected: DemoData.protected().filter { scope.contains($0.area) })
        switch screen {
        case "home", "intro":
            findings = []
            areaStates = [:]
            phase = .home
        case "scanning":
            // The first areas are done, the next two under way, the rest still waiting.
            let done = Set(areas.prefix(max(1, areas.count / 3)))
            let underWay = Set(areas.filter { !done.contains($0) }.prefix(2))
            findings.removeAll { !done.contains($0.area) }
            for area in areas where !done.contains(area) {
                areaStates[area] = underWay.contains(area) ? .scanning : .queued
            }
            phase = .scanning
        case "queued":
            findings = []
            areaStates = Dictionary(uniqueKeysWithValues: areas.map { ($0, .queued) })
            phase = .scanning
        case "quiet":
            // The last three areas have nothing to offer, one of them because it was skipped.
            let quiet = Array(areas.suffix(3))
            show(findings: findings.filter { !quiet.contains($0.area) }, protected: protected)
            if let skipped = quiet.first {
                markSkipped(skipped, reason: "The tool did not answer, so this area was not measured.")
            }
        case "manager":
            openArea = areas.first { !findings(in: $0).isEmpty } ?? areas.first
        case "review":
            showingReview = true
        case "cleaning":
            cleanProgress = CleanProgress(fraction: 0.62, status: "Deleting \(areas.contains(.xcode) ? "~/Library/Developer/Xcode/DerivedData" : "~/Library/Caches/JetBrains")")
            phase = .cleaning
        default:
            break
        }
    }
    #endif

    // MARK: Areas

    var scannedAreas: [Area] { areas.filter { areaStates[$0] != nil && areaStates[$0] != .idle } }

    var finishedAreaCount: Int {
        scannedAreas.count { area in
            switch areaStates[area] {
            case .finished, .skipped: true
            default: false
            }
        }
    }

    func areaState(for area: Area) -> AreaState { areaStates[area] ?? .idle }

    func skipReason(for area: Area) -> String? {
        if case .skipped(let reason) = areaStates[area] { return reason }
        return nil
    }

    /// How a group's areas are doing, for the one entry that stands for all of them.
    func state(of group: AreaGroup) -> AreaState { Self.combined(group.areas.map(areaState)) }

    /// How an entry of the clean-up is doing: a group as one, or a single area.
    func state(of item: SidebarItem) -> AreaState {
        switch item {
        case .group(let group): state(of: group)
        case .overview, .space, .duplicates, .apps, .performance, .protection, .activity: .idle
        }
    }

    /// Several areas' states as one: scanning until the last of them is done, and skipped only when
    /// every one that was looked at was. Areas the scan left out do not count.
    static func combined(_ states: [AreaState]) -> AreaState {
        let states = states.filter { $0 != .idle }
        guard let first = states.first else { return .idle }
        if states.allSatisfy({ $0 == .queued }) { return .queued }
        if states.contains(where: { $0 == .queued || $0 == .scanning }) { return .scanning }
        // Only finished and skipped areas are left.
        return states.contains(.finished) ? .finished : first
    }

    /// The areas with the most found, largest first.
    func largestAreas(_ count: Int) -> [(area: Area, size: Int64)] {
        areas.map { ($0, foundSize(in: $0)) }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.prefix(count).map { $0 }
    }

    // MARK: Selection

    func isSelected(_ item: FindingItem) -> Bool { selection.contains(item.id) }

    func binding(for item: FindingItem) -> Binding<Bool> {
        Binding(
            get: { self.selection.contains(item.id) },
            set: { isOn in
                if isOn { self.selection.insert(item.id) } else { self.selection.remove(item.id) }
            }
        )
    }

    /// One binding per item, for a checkbox that shows a dash when only some are ticked.
    func itemBindings(for finding: Finding) -> [Binding<Bool>] {
        finding.items.map(binding(for:))
    }

    /// What a scan ticks by itself: the kinds switched on in Settings, less what their scanners keep by default.
    private var smartSelection: Set<String> { Set(findings.smartSelection(settings.smartKinds).map(\.id)) }

    /// The ticks a preset stands for, among the items of one area or of every area.
    private func ticks(for preset: SelectionPreset, in area: Area?) -> Set<String> {
        let scope = area.map(findings(in:)) ?? findings
        return switch preset {
        case .smart: Set(scope.smartSelection(settings.smartKinds).map(\.id))
        case .everything: Set(scope.flatMap { $0.items.map(\.id) })
        case .nothing: []
        }
    }

    /// Sets every tick of one area, or of the whole clean-up, to what the preset stands for. Everything
    /// is everything, whatever its aftermath: the confirmation still says what that includes.
    func select(_ preset: SelectionPreset, in area: Area? = nil) {
        let scope = area.map(findings(in:)) ?? findings
        selection.subtract(scope.flatMap { $0.items.map(\.id) })
        selection.formUnion(ticks(for: preset, in: area))
    }

    /// The preset the ticks of one area, or of the whole clean-up, amount to right now. Nil once
    /// rows have been ticked by hand into something no preset describes.
    func preset(in area: Area? = nil) -> SelectionPreset? {
        let scope = area.map(findings(in:)) ?? findings
        let ticked = selection.intersection(scope.flatMap { $0.items.map(\.id) })
        // Smart is asked first: where it ticks everything there is, or nothing, that is still Smart.
        return SelectionPreset.allCases.first { ticks(for: $0, in: area) == ticked }
    }

    func findings(in area: Area) -> [Finding] { findings.filter { $0.area == area } }
    func protected(in area: Area) -> [ProtectedItem] { protected.filter { $0.area == area } }

    func selectedSize(in finding: Finding) -> Int64 {
        finding.items.reduce(0) { $0 + (selection.contains($1.id) ? $1.size : 0) }
    }

    func selectedSize(in area: Area) -> Int64 {
        findings(in: area).reduce(0) { $0 + selectedSize(in: $1) }
    }

    func foundSize(in area: Area) -> Int64 {
        findings(in: area).reduce(0) { $0 + $1.size }
    }

    var foundSize: Int64 { findings.reduce(0) { $0 + $1.size } }
    var protectedSize: Int64 { protected.reduce(0) { $0 + ($1.size ?? 0) } }
    var selectedSize: Int64 { findings.reduce(0) { $0 + selectedSize(in: $1) } }
    var selectedFindingCount: Int { findings.count { finding in finding.items.contains { selection.contains($0.id) } } }

    /// Whether anything ticked has no size macOS can report, so totals are "at least".
    var selectionHasUnknownSize: Bool { selectionHasUnknownSize(in: nil) }

    /// The same for one area, or for everything when `area` is nil.
    func selectionHasUnknownSize(in area: Area?) -> Bool {
        findings.contains { finding in
            (area == nil || finding.area == area) && finding.items.contains { $0.sizeUnknown && selection.contains($0.id) }
        }
    }

    // MARK: Waiting for open apps

    /// The ticked items of one area, or of every area, that wait because an app that keeps them is
    /// open, with the apps each one waits for.
    func waitingItems(in area: Area? = nil) -> [String: [OpenApp]] {
        let scope = area.map(findings(in:)) ?? findings
        return scope.flatMap(\.items).filter { selection.contains($0.id) }.waiting(for: openApps.apps)
    }

    /// The same, as the sentence each item gets on the receipt.
    func waitingReasons(in area: Area? = nil) -> [String: String] {
        let waiting = waitingItems(in: area)
        guard !waiting.isEmpty else { return [:] }
        var reasons: [String: String] = [:]
        for item in findings.flatMap(\.items) {
            if let apps = waiting[item.id] { reasons[item.id] = Cleaner.waitingReason(item.paths.first?.path ?? item.title, for: apps) }
        }
        return reasons
    }

    /// The apps an item waits for, for the badge on its row. Empty when none of them is open.
    func keepers(of item: FindingItem) -> [OpenApp] {
        guard let key = item.keptBy else { return [] }
        return openApps.apps.filter { $0.keeps(key) }
    }

    /// The open apps something ticked waits for, each with how much that is, the largest first. A
    /// group that waits as a whole, as DerivedData does for Xcode, counts for its app as well.
    func blockingApps(in area: Area? = nil) -> [BlockingApp] {
        var blocking: [String: BlockingApp] = [:]
        func add(_ app: OpenApp, _ size: Int64) {
            blocking[app.bundleID, default: BlockingApp(app: app, size: 0)].size += size
        }
        let plan = plan(in: area)
        let blocked = blockedSteps(in: plan)
        for step in plan.steps where blocked[step.id] != nil {
            if case .app(let bundleID, let name)? = step.waitsFor { add(OpenApp(bundleID: bundleID, name: name), step.size) }
        }
        let waiting = waitingItems(in: area)
        // An item of a group that waits as a whole is already counted with its group.
        let wholeSteps = Set(blocked.keys)
        for finding in findings where !wholeSteps.contains(finding.id) {
            for item in finding.items {
                guard let apps = waiting[item.id] else { continue }
                for app in apps { add(app, item.size) }
            }
        }
        return blocking.values.sorted { ($0.size, $1.app.name) > ($1.size, $0.app.name) }
    }

    /// What a clean of one area, or of every area, would remove right now: what is ticked, less what
    /// waits for something that is open. The round button and the confirmation both show it.
    func cleanableSize(in area: Area? = nil) -> Int64 {
        let plan = plan(in: area)
        return plan.size(leavingOut: Set(blockedSteps(in: plan).keys), waiting: Set(waitingItems(in: area).keys))
    }

    /// How much of what is ticked waits for something that is open.
    func waitingSize(in area: Area? = nil) -> Int64 {
        max(0, selectedSize(in: area) - cleanableSize(in: area))
    }

    private func selectedSize(in area: Area?) -> Int64 { area.map { selectedSize(in: $0) } ?? selectedSize }

    /// Asks an app to quit, as its own Quit command would. What waited for it is cleaned once it is gone.
    func quit(_ app: OpenApp) {
        openApps.quit(app)
    }

    /// What the menu bar offers and its button removes: the Smart selection, whatever is ticked just now.
    var smartSize: Int64 { findings.smartSelection(settings.smartKinds).reduce(0) { $0 + $1.size } }

    // MARK: Never Suggest

    /// Hides the item from this and every future scan, and lists it under Protected instead.
    func neverSuggest(_ item: FindingItem, in finding: Finding) {
        let path = item.paths.first?.standardizedFileURL.path ?? item.id
        settings.addNeverSuggest(path: path, title: item.title)
        selection.remove(item.id)
        protected.insert(ProtectedItem(
            id: "never/\(item.id)", area: finding.area, title: item.title,
            why: "\(item.detail.prefix(80)). On your Never Suggest list", rule: .neverSuggest,
            size: item.sizeUnknown ? nil : item.size
        ), at: 0)
        findings = findings.compactMap { candidate in
            guard candidate.id == finding.id else { return candidate }
            var candidate = candidate
            candidate.items.removeAll { $0.id == item.id }
            return candidate.items.isEmpty ? nil : candidate
        }
    }

    /// Leaves everything in the item's folder alone from now on. What the folder holds comes off the
    /// list, and the folder is listed under Protected instead, the way the next scan will list it.
    func neverSuggest(folderOf item: FindingItem, in finding: Finding) {
        guard let folder = item.paths.first?.deletingLastPathComponent().standardizedFileURL else { return }
        settings.addNeverSuggest(path: folder.path, title: folder.lastPathComponent)
        let prefix = folder.path + "/"
        let isInside = { (item: FindingItem) in item.paths.contains { $0.standardizedFileURL.path.hasPrefix(prefix) } }
        selection.subtract(findings.flatMap(\.items).filter(isInside).map(\.id))
        protected.insert(LargeFileScanner.leftOut(folder, context: settings.scanContext(home: home)), at: 0)
        findings = findings.compactMap { candidate in
            var candidate = candidate
            candidate.items.removeAll(where: isInside)
            return candidate.items.isEmpty ? nil : candidate
        }
    }

    // MARK: Navigation

    /// Opens one area in the manager.
    func open(_ area: Area) {
        guard phase == .results || phase == .done else { return }
        phase = .results
        openArea = area
    }

    /// Leaves the "done" screen, or the manager, for the results.
    func showResults() {
        openArea = nil
        phase = findings.isEmpty ? .home : .results
    }

    // MARK: Cleaning

    /// Opens the confirmation for one area's ticked items, or for everything ticked.
    func review(area: Area? = nil) {
        reviewArea = area
        openApps.refresh()
        refreshActiveChecks()
        showingReview = true
    }

    /// The one-step path: put the ticks back to the Smart selection and confirm.
    func reviewSmart() {
        guard selectSmart() else { return }
        reviewArea = nil
        showingReview = selectedSize > 0
    }

    /// Puts the ticks back to the Smart selection and leaves the "done" screen for the results. False
    /// before there are any.
    @discardableResult
    func selectSmart() -> Bool {
        guard phase == .results || phase == .done else { return false }
        phase = .results
        openArea = nil
        selection = smartSelection
        return true
    }

    /// The plan the confirmation shows: one area's ticked items, or everything ticked.
    var plan: CleanPlan { plan(in: reviewArea) }

    func plan(in area: Area?) -> CleanPlan {
        CleanPlan.make(findings: area.map(findings(in:)) ?? findings, selection: selection)
    }

    /// Whether the plan on the confirmation has items of no known size, so its total is "at least".
    var planHasUnknownSize: Bool { selectionHasUnknownSize(in: reviewArea) }

    /// The guard the cleaner runs with, built from the settings.
    func safetyGuard() -> SafetyGuard {
        SafetyGuard(
            root: home,
            extraRoots: GuardRoots.temporaryFolders(),
            allowedApplications: settings.offersOldXcodes ? GuardRoots.otherXcodes() : [],
            neverSuggest: settings.neverSuggest.map(\.path),
            backupsAllowed: true
        )
    }

    func clean() {
        let area = reviewArea
        Task { await runClean(area: area) }
    }

    /// Cleans what is ticked in one area, or everywhere, and waits for it. Nil when there was nothing
    /// to do. The overview runs each clean-up this way in turn and keeps the receipts together.
    /// `unattended` leaves out every step that would ask for a password, for a clean nobody is watching.
    @discardableResult
    func runClean(area: Area?, unattended: Bool = false) async -> CleanOutcome? {
        let plan = unattended ? plan(in: area).withoutPasswordSteps : plan(in: area)
        guard !plan.isEmpty, phase == .results else { return nil }
        showingReview = false
        cleanProgress = CleanProgress(fraction: 0, status: "Getting ready")
        phase = .cleaning

        // Asked afresh at the last moment: an app may have been opened, or quit, since the confirmation.
        openApps.refresh()
        refreshActiveChecks()
        let skipping = blockedSteps(in: plan)
        let waiting = waitingReasons(in: area)
        let safety = safetyGuard()
        let scannedAt = scanFinished
        let result = await Cleaner.run(plan: plan, safety: safety, skipping: skipping, waiting: waiting, scannedAt: scannedAt) { progress in
            Task { @MainActor in self.cleanProgress = progress }
        }
        finishClean(result)
        return result
    }

    /// Steps that have to wait because what owns the files is open, with the reason.
    /// Nothing is quit unless the user asks for it: it may be mid-build, or running this very app.
    func blockedSteps(in plan: CleanPlan) -> [String: String] {
        var blocked: [String: String] = [:]
        for step in plan.steps {
            guard let check = step.waitsFor, isActive(check, for: step.id) else { continue }
            blocked[step.id] = check.skipReason
        }
        return blocked
    }

    /// Whether a check holds its finding back right now. An app is asked about as it is this moment,
    /// which costs nothing and follows it quitting. A background process costs a launch to ask about,
    /// so the answer from the last look is used: `refreshActiveChecks()` takes a new one.
    private func isActive(_ check: InUseCheck, for findingID: String) -> Bool {
        switch check {
        case .app(let bundleID, _): openApps.isOpen(bundleID: bundleID)
        case .process: activeChecksByFinding[findingID] != nil
        }
    }

    func activeChecks() -> [String: InUseCheck] {
        var active: [String: InUseCheck] = [:]
        for finding in findings {
            if let check = finding.waitsFor, isActive(check, for: finding.id) { active[finding.id] = check }
        }
        return active
    }

    func refreshActiveChecks() {
        var active: [String: InUseCheck] = [:]
        var cache: [InUseCheck: Bool] = [:]
        for finding in findings {
            guard let check = finding.waitsFor else { continue }
            if cache[check] == nil { cache[check] = InUse.isActive(check) }
            if cache[check] == true { active[finding.id] = check }
        }
        activeChecksByFinding = active
    }

    private func finishClean(_ result: CleanOutcome) {
        take(result)
        didClean(result)
        didRecord(.clean(result, part: ActivityRecord.Part(group)))
    }

    /// Takes in what a clean did: the receipt, and the findings that are left.
    private func take(_ result: CleanOutcome) {
        let cleaned = result.cleanedItemIDs
        findings = findings.compactMap { finding in
            var finding = finding
            finding.items.removeAll { cleaned.contains($0.id) }
            return finding.items.isEmpty ? nil : finding
        }
        selection.subtract(cleaned)
        outcome = result
        reviewArea = nil
        openArea = nil
        phase = .done
    }

    func copyShellScript() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(plan.shellScript(), forType: .string)
    }
}
