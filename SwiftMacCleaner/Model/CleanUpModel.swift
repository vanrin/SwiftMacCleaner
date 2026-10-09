//
//  CleanUpModel.swift
//  SwiftMacCleaner
//

import AppKit
import Observation
import SwiftUI

/// One clean-up from start to finish: a scan over its group's areas, what it found, what is ticked, the
/// confirmation, the clean and its receipt. System Clean Up, Developer Clean Up and Large old downloads
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
    /// Which clean-up this is.
    let group: AreaGroup
    /// The areas this clean-up may look at, in the order they are listed.
    var areas: [Area] { group.areas }
    /// Called when a scan ends, so the owner can note the time and refresh the disk figure.
    @ObservationIgnored var didScan: () -> Void = {}
    /// Called after a clean, so the owner can refresh the disk figure and the offer to put things back.
    @ObservationIgnored var didClean: (CleanOutcome) -> Void = { _ in }

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
    /// Set by Quick Clean: open the confirmation as soon as the scan ends, with only Safe items ticked.
    @ObservationIgnored private var reviewWhenScanned = false

    init(home: URL, settings: AppSettings, group: AreaGroup) {
        self.home = home
        self.settings = settings
        self.group = group
    }

    /// Whether a scan is under way or a clean, during which the overview counts this clean-up as busy.
    var isBusy: Bool { phase == .scanning || phase == .cleaning }

    // MARK: Scanning

    /// Scans the given areas, or every area of this clean-up. With `thenReviewSafe`, only the Safe
    /// tier is ticked when the scan ends and the confirmation opens on its own.
    func startScan(areas requested: [Area]? = nil, thenReviewSafe: Bool = false) {
        let scanned = requested ?? areas
        guard !scanned.isEmpty else { return }
        scanTask?.cancel()
        reviewWhenScanned = thenReviewSafe

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
        findings.sort { ($0.tier, -$0.size) < ($1.tier, -$1.size) }
        protected.sort { ($0.size ?? -1) > ($1.size ?? -1) }
        selection = Set(findings.flatMap { finding in
            finding.items.filter { $0.preselected ?? (finding.tier == .safe) }.map(\.id)
        })
        scanDuration = Date().timeIntervalSince(scanStarted)
        scanFinished = Date()
        refreshActiveChecks()
        phase = findings.isEmpty && areaStates.values.allSatisfy({ $0 == .idle }) ? .home : .results
        didScan()
        if reviewWhenScanned {
            reviewWhenScanned = false
            reviewSafe()
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
        case .overview, .space, .apps, .performance: .idle
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

    /// Ticks every item of the area, whatever its tier. The confirmation still says what that includes.
    func selectAll(in area: Area) {
        selection.formUnion(findings(in: area).flatMap { $0.items.map(\.id) })
    }

    /// Ticks only what the scan ticked by itself: the Safe tier, less what its scanner keeps by default.
    func selectSafe(in area: Area) {
        selectNone(in: area)
        selection.formUnion(findings(in: area).safeDefaults.map(\.id))
    }

    func selectNone(in area: Area) {
        selection.subtract(findings(in: area).flatMap { $0.items.map(\.id) })
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

    /// What the menu bar offers: the part of the Safe tier its button removes. Less than the tier
    /// adds up to whenever something in it is kept by default.
    var safeSize: Int64 { findings.safeDefaults.reduce(0) { $0 + $1.size } }

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
        showingReview = true
    }

    /// The menu bar's one-click path: tick the Safe tier from the last scan and confirm.
    func reviewSafe() {
        guard selectSafeDefaults() else { return }
        reviewArea = nil
        showingReview = selectedSize > 0
    }

    /// Ticks only what the scan ticked by itself, the Safe tier less what its scanners keep by default,
    /// and leaves the "done" screen for the results. False before there are any.
    @discardableResult
    func selectSafeDefaults() -> Bool {
        guard phase == .results || phase == .done else { return false }
        phase = .results
        openArea = nil
        selection = Set(findings.safeDefaults.map(\.id))
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
            extraRoots: GuardRoots.userTemporaryFolders(),
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
    @discardableResult
    func runClean(area: Area?) async -> CleanOutcome? {
        let plan = plan(in: area)
        guard !plan.isEmpty, phase == .results else { return nil }
        showingReview = false
        cleanProgress = CleanProgress(fraction: 0, status: "Getting ready")
        phase = .cleaning

        let skipping = blockedSteps(in: plan)
        let safety = safetyGuard()
        let scannedAt = scanFinished
        let result = await Cleaner.run(plan: plan, safety: safety, skipping: skipping, scannedAt: scannedAt) { progress in
            Task { @MainActor in self.cleanProgress = progress }
        }
        finishClean(result)
        return result
    }

    /// Steps that have to wait because what owns the files is open, with the reason.
    /// Nothing is quit on the user's behalf: it may be mid-build, or running this very app.
    func blockedSteps(in plan: CleanPlan) -> [String: String] {
        var blocked: [String: String] = [:]
        for step in plan.steps {
            guard let check = step.waitsFor, InUse.isActive(check) else { continue }
            blocked[step.id] = check.skipReason
        }
        return blocked
    }

    func activeChecks() -> [String: InUseCheck] { activeChecksByFinding }

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
