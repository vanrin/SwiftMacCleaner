//
//  AppModel.swift
//  Mac Disk Cleaner
//

import AppKit
import Observation
import SwiftUI
import UserNotifications

enum SidebarItem: Hashable {
    case overview
    case area(Area)
    /// Largest Folders, which is independent of the clean-up scan.
    case space
}

/// Which apps are running, asked of the workspace. Kept apart so a non-UI caller can ask too.
nonisolated enum RunningApps {
    static func isRunning(bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }
}

@Observable
final class AppModel {
    enum Phase {
        case home, scanning, results, cleaning, done
    }

    enum AreaState: Equatable {
        case idle, queued, scanning, finished
        case skipped(String)
    }

    let settings: AppSettings
    /// The folder everything is cleaned inside. Tests pass a temporary folder.
    let home: URL
    let space: SpaceModel

    private(set) var phase: Phase = .home
    private(set) var disk = DiskInfo.current()
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
    /// Items from the last clean that are still in the Trash and can be put back.
    private(set) var putBackPending: PutBack.Manifest?
    private(set) var putBackMessage: String?

    var sidebarSelection: SidebarItem = .overview
    var showingReview = false
    /// Areas switched off on the home screen. Stored this way so a new area starts switched on.
    var disabledAreas: Set<Area> {
        didSet { UserDefaults.standard.set(disabledAreas.map(\.rawValue), forKey: "disabledAreas") }
    }

    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var scanStarted = Date()
    /// Set by Quick Clean: open the confirmation as soon as the scan ends, with only Safe items ticked.
    @ObservationIgnored private var reviewWhenScanned = false

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser, settings: AppSettings = AppSettings()) {
        self.home = home
        self.settings = settings
        space = SpaceModel(home: home)
        disabledAreas = Set((UserDefaults.standard.stringArray(forKey: "disabledAreas") ?? []).compactMap(Area.init(rawValue:)))
        putBackPending = PutBack.pending(home: home)
        #if DEBUG
        if let flag = CommandLine.arguments.firstIndex(of: "--demo") {
            let arguments = Array(CommandLine.arguments.dropFirst(flag + 1))
            loadDemo(screen: arguments.first ?? "results", arguments: Array(arguments.dropFirst()))
        }
        #endif
    }

    var enabledAreas: Set<Area> { Set(Area.allCases).subtracting(disabledAreas) }

    #if DEBUG
    /// Shows the given findings as if a scan had just finished. For demo mode and tests.
    func show(findings newFindings: [Finding], protected newProtected: [ProtectedItem] = []) {
        findings = newFindings
        protected = newProtected
        areaStates = Dictionary(uniqueKeysWithValues: Area.allCases.map { ($0, .finished) })
        finishScan()
        phase = .results
    }

    /// Fills the app with made-up results and opens the named screen. See `DemoData`.
    private func loadDemo(screen: String, arguments: [String]) {
        show(findings: DemoData.findings(), protected: DemoData.protected())
        switch screen {
        case "home":
            phase = .home
            findings = []
        case "space":
            // `--demo space <folder> [steps]` measures that folder straight away, then steps into its
            // largest folder that many times. Without a folder it shows the intro.
            sidebarSelection = .space
            if let path = arguments.first {
                let folder = URL(fileURLWithPath: path, isDirectory: true)
                space.start(root: folder, title: folder.lastPathComponent)
                let steps = arguments.dropFirst().first.flatMap(Int.init) ?? 0
                Task {
                    while space.phase == .measuring { try? await Task.sleep(for: .milliseconds(100)) }
                    for _ in 0..<steps {
                        if let largest = space.current?.children.first { space.open(largest) }
                    }
                }
            }
        case "scanning":
            let done: Set<Area> = [.xcode, .projects, .android]
            findings.removeAll { !done.contains($0.area) }
            for area in Area.allCases where !done.contains(area) {
                areaStates[area] = area == .containers || area == .packageCaches ? .scanning : .queued
            }
            phase = .scanning
        case "xcode":
            sidebarSelection = .area(.xcode)
        case "projects":
            sidebarSelection = .area(.projects)
        case "leftovers":
            sidebarSelection = .area(.leftovers)
        case "review":
            showingReview = true
        case "done":
            let result = DemoData.outcome(for: findings, freeBefore: disk.free)
            disk.free = result.freeAfter
            finishClean(result)
            disk.free = result.freeAfter
            putBackPending = PutBack.Manifest(date: result.started, items: result.trashed)
        default:
            break
        }
    }
    #endif

    /// The app can only see its own container while App Sandbox is on.
    var isSandboxed: Bool { ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil }

    // MARK: Scanning

    func startScan() {
        reviewWhenScanned = false
        notifyWhenScanned = false
        beginScan()
    }

    // MARK: Background check

    static let weeklyInterval: TimeInterval = 7 * 86_400

    @ObservationIgnored private var checkTimer: Timer?
    /// Set by the weekly check: say what the scan found instead of showing it.
    @ObservationIgnored private var notifyWhenScanned = false

    /// Keeps the disk figure fresh and, once a week, scans on its own while the app sits idle.
    func startBackgroundChecks() {
        guard checkTimer == nil else { return }
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.backgroundTick() }
        }
        backgroundTick()
    }

    func backgroundTick() {
        disk = DiskInfo.current()
        if phase == .results { refreshActiveChecks() }
        guard settings.weeklyCheck, phase == .home, scanTask == nil, isWeeklyCheckDue else { return }
        notifyWhenScanned = true
        reviewWhenScanned = false
        beginScan()
    }

    var isWeeklyCheckDue: Bool {
        guard let last = settings.lastScanDate else { return true }
        return Date().timeIntervalSince(last) >= Self.weeklyInterval
    }

    /// What the Safe tier adds up to in the last scan, which is what the menu bar offers.
    var safeSize: Int64 { findings.filter { $0.tier == .safe }.reduce(0) { $0 + $1.size } }

    /// The areas with the most found, largest first.
    func largestAreas(_ count: Int) -> [(area: Area, size: Int64)] {
        Area.allCases.map { ($0, foundSize(in: $0)) }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.prefix(count).map { $0 }
    }

    /// The menu bar's one-click path: tick the Safe tier from the last scan and confirm, or scan first.
    func cleanSafe() {
        switch phase {
        case .results, .done:
            phase = .results
            selection = Set(findings.filter { $0.tier == .safe }.flatMap { finding in
                finding.items.filter { $0.preselected ?? true }.map(\.id)
            })
            sidebarSelection = .overview
            showingReview = selectedSize > 0
        default:
            quickClean()
        }
    }

    private func notifyAboutScan() {
        let safe = safeSize
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = safe > 0 ? "\(ByteFormat.string(safe)) can go safely" : "Your disk is in good shape"
            content.body = safe > 0
                ? "Build output and caches that rebuild themselves. Open Mac Disk Cleaner to review and clean."
                : "The weekly check found nothing worth removing."
            center.add(UNNotificationRequest(identifier: "weekly-check", content: content, trigger: nil))
        }
    }

    /// Scans everything, keeps only the Safe tier ticked, and goes straight to the confirmation.
    func quickClean() {
        reviewWhenScanned = true
        beginScan()
    }

    private func beginScan() {
        scanTask?.cancel()
        let areas = Area.allCases.filter(enabledAreas.contains)
        guard !areas.isEmpty else { return }

        findings = []
        protected = []
        selection = []
        outcome = nil
        putBackMessage = nil
        unreadableFolders = []
        areaStates = Dictionary(uniqueKeysWithValues: Area.allCases.map { ($0, areas.contains($0) ? .queued : .idle) })
        sidebarSelection = .overview
        showingReview = false
        phase = .scanning
        scanStarted = Date()

        var context = settings.scanContext(home: home)
        if !settings.offersSnapshots { context.excluded.append(SnapshotScanner.snapshotsItemID) }
        if !settings.offersOldXcodes { context.excluded.append(XcodeScanner.oldXcodesFindingID) }
        scanTask = Task {
            for await event in ScanEngine.events(areas: areas, context: context) {
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
        settings.lastScanDate = scanFinished
        disk = DiskInfo.current()
        refreshActiveChecks()
        phase = findings.isEmpty && areaStates.values.allSatisfy({ $0 == .idle }) ? .home : .results
        if notifyWhenScanned {
            notifyWhenScanned = false
            notifyAboutScan()
        }
        if reviewWhenScanned {
            reviewWhenScanned = false
            selection = Set(findings.filter { $0.tier == .safe }.flatMap { finding in
                finding.items.filter { $0.preselected ?? true }.map(\.id)
            })
            showingReview = selectedSize > 0
        }
    }

    var scannedAreas: [Area] { Area.allCases.filter { areaStates[$0] != nil && areaStates[$0] != .idle } }

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

    func binding(for area: Area) -> Binding<Bool> {
        Binding(
            get: { !self.disabledAreas.contains(area) },
            set: { isOn in
                if isOn { self.disabledAreas.remove(area) } else { self.disabledAreas.insert(area) }
            }
        )
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
    var selectionHasUnknownSize: Bool {
        findings.contains { $0.items.contains { $0.sizeUnknown && selection.contains($0.id) } }
    }

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

    func select(_ item: SidebarItem) {
        switch (phase, item) {
        case (_, .space):
            sidebarSelection = .space
        case (.results, _):
            sidebarSelection = item
        case (.done, .area):
            phase = .results
            sidebarSelection = item
        default:
            sidebarSelection = .overview
        }
    }

    /// Leaves the "done" screen for what is still on the list.
    func showResults() {
        sidebarSelection = .overview
        phase = findings.isEmpty ? .home : .results
    }

    // MARK: Cleaning

    var plan: CleanPlan { CleanPlan.make(findings: findings, selection: selection) }

    func isRunning(bundleID: String) -> Bool { RunningApps.isRunning(bundleID: bundleID) }

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
        let plan = plan
        guard !plan.isEmpty, phase == .results else { return }
        showingReview = false
        cleanProgress = CleanProgress(fraction: 0, status: "Getting ready")
        phase = .cleaning

        let skipping = blockedSteps(in: plan)
        let safety = safetyGuard()
        let scannedAt = scanFinished
        Task {
            let result = await Cleaner.run(plan: plan, safety: safety, skipping: skipping, scannedAt: scannedAt) { progress in
                Task { @MainActor in self.cleanProgress = progress }
            }
            finishClean(result)
        }
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

    /// Findings whose in-use check was active the last time it was looked at, for the badges on rows.
    /// Asking costs a process launch, so it happens after a scan and on the background tick, not per render.
    private(set) var activeChecksByFinding: [String: InUseCheck] = [:]

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
        let cleaned = result.cleanedItemIDs
        findings = findings.compactMap { finding in
            var finding = finding
            finding.items.removeAll { cleaned.contains($0.id) }
            return finding.items.isEmpty ? nil : finding
        }
        selection.subtract(cleaned)
        outcome = result
        PutBack.save(result, home: home)
        putBackPending = PutBack.pending(home: home)
        putBackMessage = nil
        disk = DiskInfo.current()
        sidebarSelection = .overview
        phase = .done
    }

    // MARK: Put Back

    /// Returns everything the last clean moved to the Trash to where it was.
    func putBack() {
        guard let manifest = putBackPending else { return }
        let count = manifest.items.count
        let failures = PutBack.restore(manifest, home: home)
        putBackPending = PutBack.pending(home: home)
        disk = DiskInfo.current()
        if failures.isEmpty {
            putBackMessage = "\(count == 1 ? "1 item is" : "\(count) items are") back where \(count == 1 ? "it was" : "they were"). "
                + "They will be offered again on the next scan unless you mark them Never Suggest."
        } else {
            putBackMessage = "\(count - failures.count) of \(count) put back. " + failures.joined(separator: " ")
        }
    }

    /// Forgets the last clean's Trash items without touching them, once the user has emptied the Trash.
    func refreshPutBack() {
        putBackPending = PutBack.pending(home: home)
    }

    // MARK: Small actions

    func copyShellScript() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(plan.shellScript(), forType: .string)
    }

    func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }

    /// Whether macOS lets the app read protected folders. There is no API to ask, so the check
    /// tries to open a file that only Full Disk Access can reach.
    var hasFullDiskAccess: Bool {
        let probe = home.appending(path: "Library/Application Support/com.apple.TCC/TCC.db")
        guard let handle = try? FileHandle(forReadingFrom: probe) else { return false }
        try? handle.close()
        return true
    }

    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    func showInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openTrash() {
        NSWorkspace.shared.open(home.appending(path: ".Trash"))
    }
}
