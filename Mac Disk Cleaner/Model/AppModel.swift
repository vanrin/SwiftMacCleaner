//
//  AppModel.swift
//  Mac Disk Cleaner
//

import AppKit
import Observation
import SwiftUI

enum SidebarItem: Hashable {
    case overview
    case area(Area)
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

    let settings = AppSettings()
    /// The folder everything is cleaned inside. Tests pass a temporary folder.
    let home: URL

    private(set) var phase: Phase = .home
    private(set) var disk = DiskInfo.current()
    private(set) var areaStates: [Area: AreaState] = [:]
    private(set) var findings: [Finding] = []
    private(set) var selection: Set<String> = []
    /// Folders macOS would not let the last scan read.
    private(set) var unreadableFolders: [String] = []
    private(set) var scanDuration: TimeInterval = 0
    private(set) var cleanProgress = CleanProgress(fraction: 0, status: "")
    private(set) var outcome: CleanOutcome?

    var sidebarSelection: SidebarItem = .overview
    var showingReview = false
    var enabledAreas: Set<Area> {
        didSet { UserDefaults.standard.set(enabledAreas.map(\.rawValue), forKey: "enabledAreas") }
    }

    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var scanStarted = Date()

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home
        if let stored = UserDefaults.standard.stringArray(forKey: "enabledAreas") {
            enabledAreas = Set(stored.compactMap(Area.init(rawValue:)))
        } else {
            enabledAreas = Set(Area.allCases)
        }
        #if DEBUG
        if let flag = CommandLine.arguments.firstIndex(of: "--demo") {
            loadDemo(screen: CommandLine.arguments.dropFirst(flag + 1).first ?? "results")
        }
        #endif
    }

    #if DEBUG
    /// Shows the given findings as if a scan had just finished. For demo mode and tests.
    func show(findings newFindings: [Finding]) {
        findings = newFindings
        areaStates = Dictionary(uniqueKeysWithValues: Area.allCases.map { ($0, .finished) })
        finishScan()
        phase = .results
    }

    /// Fills the app with made-up results and opens the named screen. See `DemoData`.
    private func loadDemo(screen: String) {
        show(findings: DemoData.findings())
        switch screen {
        case "scanning":
            let done: Set<Area> = [.xcode, .projects, .android]
            findings.removeAll { !done.contains($0.area) }
            for area in Area.allCases where !done.contains(area) {
                areaStates[area] = area == .docker || area == .packageCaches ? .scanning : .queued
            }
            phase = .scanning
        case "xcode":
            sidebarSelection = .area(.xcode)
        case "projects":
            sidebarSelection = .area(.projects)
        case "review":
            showingReview = true
        case "done":
            let result = DemoData.outcome(for: findings, freeBefore: disk.free)
            disk.free = result.freeAfter
            finishClean(result)
            disk.free = result.freeAfter
        default:
            break
        }
    }
    #endif

    /// The app can only see its own container while App Sandbox is on.
    var isSandboxed: Bool { ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil }

    // MARK: Scanning

    func startScan() {
        scanTask?.cancel()
        let areas = Area.allCases.filter(enabledAreas.contains)
        guard !areas.isEmpty else { return }

        findings = []
        selection = []
        outcome = nil
        unreadableFolders = []
        areaStates = Dictionary(uniqueKeysWithValues: Area.allCases.map { ($0, areas.contains($0) ? .queued : .idle) })
        sidebarSelection = .overview
        showingReview = false
        phase = .scanning
        scanStarted = Date()

        let context = settings.scanContext()
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
            unreadableFolders += result.unreadable
            areaStates[area] = result.skipReason.map(AreaState.skipped) ?? .finished
        }
    }

    private func finishScan() {
        findings.sort { ($0.tier, -$0.size) < ($1.tier, -$1.size) }
        selection = Set(findings.flatMap { finding in
            finding.items.filter { $0.preselected ?? (finding.tier == .safe) }.map(\.id)
        })
        scanDuration = Date().timeIntervalSince(scanStarted)
        disk = DiskInfo.current()
        phase = findings.isEmpty && areaStates.values.allSatisfy({ $0 == .idle }) ? .home : .results
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
            get: { self.enabledAreas.contains(area) },
            set: { isOn in
                if isOn { self.enabledAreas.insert(area) } else { self.enabledAreas.remove(area) }
            }
        )
    }

    func findings(in area: Area) -> [Finding] { findings.filter { $0.area == area } }

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
    var selectedSize: Int64 { findings.reduce(0) { $0 + selectedSize(in: $1) } }
    var selectedFindingCount: Int { findings.count { selectedSize(in: $0) > 0 } }

    // MARK: Navigation

    func select(_ item: SidebarItem) {
        switch (phase, item) {
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

    func isRunning(bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    func clean() {
        let plan = plan
        guard !plan.isEmpty, phase == .results else { return }
        showingReview = false
        cleanProgress = CleanProgress(fraction: 0, status: "Getting ready")
        phase = .cleaning

        let skipping = blockedSteps(in: plan)
        Task {
            let result = await Cleaner.run(plan: plan, safety: SafetyGuard(root: home), skipping: skipping) { progress in
                Task { @MainActor in self.cleanProgress = progress }
            }
            finishClean(result)
        }
    }

    /// Steps that have to wait because the app that owns the files is open, with the reason.
    /// The app is never quit on the user's behalf: it may be mid-build, or running this very app.
    func blockedSteps(in plan: CleanPlan) -> [String: String] {
        var blocked: [String: String] = [:]
        for step in plan.steps {
            guard let bundleID = step.quitBundleID, isRunning(bundleID: bundleID) else { continue }
            blocked[step.id] = "Xcode was open, so this was left alone. Quit Xcode and clean again to include it."
        }
        return blocked
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
        disk = DiskInfo.current()
        sidebarSelection = .overview
        phase = .done
    }

    // MARK: Small actions

    func copyShellScript() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(plan.shellScript(), forType: .string)
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
