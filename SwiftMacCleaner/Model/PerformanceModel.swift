//
//  PerformanceModel.swift
//  SwiftMacCleaner
//

import AppKit
import Observation
import SwiftUI

/// State behind the Performance screen: the maintenance tasks and which are worth running, the login
/// items, the launch agents and daemons, and whatever the user has ticked.
@Observable
final class PerformanceModel {
    enum Phase {
        case idle, scanning, summary, managing, running, done
    }

    /// The three parts of the manager.
    enum Section: String, CaseIterable, Identifiable {
        case maintenance, loginItems, backgroundItems

        var id: String { rawValue }
        var title: String {
            switch self {
            case .maintenance: "Maintenance Tasks"
            case .loginItems: "Login Items"
            case .backgroundItems: "Background Items"
            }
        }
        var detail: String {
            switch self {
            case .maintenance: "Chores macOS leaves to you. The recommended ones are ticked; run any of the others whenever you like."
            case .loginItems: "Apps that open by themselves when you log in. Take off the ones you do not need at every start."
            case .backgroundItems: "Launch agents and daemons other makers installed, which start on their own whether or not their app is open."
            }
        }
        /// What the round button does for this part.
        var verb: String { self == .maintenance ? "Run" : "Remove" }
        var glyph: ImageResource {
            switch self {
            case .maintenance: .glyphMaintenance
            case .loginItems: .glyphLoginItems
            case .backgroundItems: .glyphBackgroundItems
            }
        }
    }

    /// What a run did, which decides how the result is worded.
    struct Run {
        var section: Section
        var done: Int
        var total: Int
        var gained: Int64
    }

    let home: URL
    let settings: AppSettings
    /// Called after a run, so the owner can refresh the disk figure and the offer to put things back.
    @ObservationIgnored var didRun: (CleanOutcome) -> Void = { _ in }

    private(set) var phase: Phase = .idle
    private(set) var progress = "Looking around"
    private(set) var checks: [MaintenanceCheck] = []
    private(set) var loginItems: [LoginItem] = []
    /// Why the login items could not be read, when they could not.
    private(set) var loginItemsFailure: String?
    private(set) var backgroundItems: [BackgroundItem] = []
    /// What the look at the launch folders could not read, as sentences.
    private(set) var backgroundIssues: [String] = []
    private(set) var selectedTasks: Set<MaintenanceTask> = []
    private(set) var selectedLoginItems: Set<String> = []
    private(set) var selectedBackgroundItems: Set<String> = []
    /// Tasks whose in-use check was active the last time it was looked at: Mail open, for one.
    private(set) var blockedTasks: Set<MaintenanceTask> = []
    private(set) var runProgress = CleanProgress(fraction: 0, status: "")
    private(set) var outcome: CleanOutcome?
    private(set) var run = Run(section: .maintenance, done: 0, total: 0, gained: 0)

    var section: Section = .maintenance
    var search = ""
    var showingReview = false

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var scanned: Date?

    init(home: URL, settings: AppSettings) {
        self.home = home
        self.settings = settings
    }

    // MARK: Scanning

    func startScan() {
        task?.cancel()
        checks = []
        loginItems = []
        loginItemsFailure = nil
        backgroundItems = []
        backgroundIssues = []
        selectedTasks = []
        selectedLoginItems = []
        selectedBackgroundItems = []
        outcome = nil
        search = ""
        showingReview = false
        progress = "Weighing up the maintenance tasks"
        phase = .scanning

        let lastRuns = settings.lastMaintenanceRuns
        let ownBundleID = Bundle.main.bundleIdentifier ?? "com.thetinydev.SwiftMacCleaner"
        task = Task { [home] in
            let facts = await MaintenanceScanner.gather(home: home)
            guard !Task.isCancelled else { return }
            checks = MaintenanceScanner.checks(facts: facts, lastRuns: lastRuns)
            progress = "Reading your login items"
            let login = await Task.detached { LoginItemScanner.scan() }.value
            guard !Task.isCancelled else { return }
            loginItems = login.items
            loginItemsFailure = login.failure
            progress = "Reading the launch agents and daemons"
            let background = await BackgroundItemScanner.scan(home: home, ownBundleID: ownBundleID)
            guard !Task.isCancelled else { return }
            backgroundItems = background.items
            backgroundIssues = background.issues
            selectedTasks = Set(checks.filter(\.isRecommended).map(\.task))
            scanned = Date()
            refreshBlocked()
            phase = .summary
        }
    }

    func stop() {
        task?.cancel()
        phase = .idle
    }

    /// Forgets the scan and goes back to the opening screen.
    func reset() {
        task?.cancel()
        showingReview = false
        phase = .idle
    }

    // MARK: Navigation

    func manage(_ section: Section) {
        self.section = section
        search = ""
        refreshBlocked()
        phase = .managing
    }

    func showSummary() {
        guard phase == .managing || phase == .done else { return }
        phase = .summary
    }

    /// The tile's shortcut: tick what is recommended and go straight to the confirmation.
    func runRecommended() {
        selectedTasks = Set(recommended.map(\.task))
        manage(.maintenance)
        refreshBlocked()
        showingReview = !selectedTasks.isEmpty
    }

    // MARK: What was found

    var recommended: [MaintenanceCheck] { checks.filter(\.isRecommended) }

    func check(for task: MaintenanceTask) -> MaintenanceCheck? { checks.first { $0.task == task } }

    /// The background items narrowed by the search.
    var visibleBackgroundItems: [BackgroundItem] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return backgroundItems }
        return backgroundItems.filter {
            $0.title.localizedStandardContains(query) || $0.label.localizedStandardContains(query)
        }
    }

    /// The login items as app icons for the tile, those that still exist.
    var loginItemIcons: [URL] { loginItems.filter(\.exists).prefix(3).map(\.path) }

    // MARK: Selection

    func binding(for task: MaintenanceTask) -> Binding<Bool> {
        Binding(
            get: { self.selectedTasks.contains(task) },
            set: { isOn in
                if isOn { self.selectedTasks.insert(task) } else { self.selectedTasks.remove(task) }
            }
        )
    }

    func binding(for item: LoginItem) -> Binding<Bool> {
        Binding(
            get: { self.selectedLoginItems.contains(item.id) },
            set: { isOn in
                if isOn { self.selectedLoginItems.insert(item.id) } else { self.selectedLoginItems.remove(item.id) }
            }
        )
    }

    func binding(for item: BackgroundItem) -> Binding<Bool> {
        Binding(
            get: { self.selectedBackgroundItems.contains(item.id) },
            set: { isOn in
                if isOn { self.selectedBackgroundItems.insert(item.id) } else { self.selectedBackgroundItems.remove(item.id) }
            }
        )
    }

    /// How many are ticked in the part on screen.
    var selectedCount: Int {
        switch section {
        case .maintenance: selectedTasks.count { task in check(for: task)?.isAvailable == true }
        case .loginItems: selectedLoginItems.count
        case .backgroundItems: selectedBackgroundItems.count
        }
    }

    func selectRecommended() {
        selectedTasks = Set(recommended.map(\.task))
    }

    func selectAll() {
        switch section {
        case .maintenance: selectedTasks = Set(checks.filter(\.isAvailable).map(\.task))
        case .loginItems: selectedLoginItems = Set(loginItems.map(\.id))
        case .backgroundItems: selectedBackgroundItems.formUnion(visibleBackgroundItems.map(\.id))
        }
    }

    func selectNone() {
        switch section {
        case .maintenance: selectedTasks = []
        case .loginItems: selectedLoginItems = []
        case .backgroundItems: selectedBackgroundItems = []
        }
    }

    // MARK: Running

    /// The plan for the part on screen.
    var plan: CleanPlan {
        switch section {
        case .maintenance:
            PerformancePlan.tasks(checks, selection: selectedTasks, mailIndex: mailIndex,
                                  executable: Bundle.main.executableURL?.path ?? CommandLine.arguments[0], uid: getuid())
        case .loginItems:
            PerformancePlan.loginItems(loginItems, selection: selectedLoginItems)
        case .backgroundItems:
            PerformancePlan.backgroundItems(backgroundItems, selection: selectedBackgroundItems, home: home, uid: getuid())
        }
    }

    /// Mail's index, when the scan found one it may compact.
    private var mailIndex: URL? {
        // The check carries only the size; the index is looked up again so a moved Mail folder is noticed.
        guard check(for: .speedUpMail)?.isAvailable == true else { return nil }
        return MaintenanceScanner.mailIndex(home: home).url
    }

    var needsPassword: Bool { plan.needsPassword }

    func isBlocked(_ task: MaintenanceTask) -> Bool { blockedTasks.contains(task) }

    /// Asks again whether Mail is open. A process check costs a launch, so it happens on the way to
    /// the manager and the confirmation, not per row.
    func refreshBlocked() {
        blockedTasks = Set(MaintenanceTask.allCases.filter { task in
            task.waitsFor.map(InUse.isActive) ?? false
        })
    }

    /// Steps that have to wait, with the sentence for the receipt.
    func blockedSteps(in plan: CleanPlan) -> [String: String] {
        var blocked: [String: String] = [:]
        for step in plan.steps {
            guard let check = step.waitsFor, InUse.isActive(check) else { continue }
            blocked[step.id] = check.skipReason
        }
        return blocked
    }

    func start() {
        let plan = plan
        guard !plan.isEmpty, phase == .managing else { return }
        let section = section
        let skipping = blockedSteps(in: plan)
        // Only the plists moved to the Trash pass through the guard; the commands do not.
        let safety = SafetyGuard(root: home, neverSuggest: settings.neverSuggest.map(\.path))
        let scannedAt = scanned
        showingReview = false
        runProgress = CleanProgress(fraction: 0, status: "Getting ready")
        phase = .running
        Task {
            let result = await Cleaner.run(plan: plan, safety: safety, skipping: skipping, scannedAt: scannedAt) { progress in
                Task { @MainActor in self.runProgress = progress }
            }
            finish(result, section: section)
        }
    }

    /// `recordsRuns` is off for the demo, whose made-up run must not count as a real one.
    private func finish(_ result: CleanOutcome, section: Section, recordsRuns: Bool = true) {
        var done = 0
        switch section {
        case .maintenance:
            let ran = tasksRun(in: result)
            if recordsRuns { settings.recordMaintenanceRun(of: ran) }
            done = ran.count
            let lastRuns = settings.lastMaintenanceRuns
            checks = checks.map { check in
                var check = check
                check.lastRun = lastRuns[check.task]
                // What ran is no longer due; the next scan weighs it up again with fresh facts.
                if ran.contains(check.task) { check.reason = nil }
                return check
            }
            selectedTasks.subtract(ran)
        case .loginItems:
            let removed = result.cleanedItemIDs
            done = loginItems.count { removed.contains(PerformancePlan.stepID(for: $0)) }
            loginItems.removeAll { removed.contains(PerformancePlan.stepID(for: $0)) }
            selectedLoginItems = selectedLoginItems.filter { id in loginItems.contains { $0.id == id } }
        case .backgroundItems:
            let removed = result.cleanedItemIDs
            done = backgroundItems.count { removed.contains(PerformancePlan.stepID(for: $0)) }
            backgroundItems.removeAll { removed.contains(PerformancePlan.stepID(for: $0)) }
            selectedBackgroundItems = selectedBackgroundItems.filter { id in backgroundItems.contains { $0.id == id } }
        }
        run = Run(section: section, done: done, total: result.steps.count, gained: result.reclaimed)
        outcome = result
        refreshBlocked()
        didRun(result)
        phase = .done
    }

    /// The tasks a run carried out: every user task that went through, and from the one step that runs
    /// as root, every task the script did not report as failed.
    func tasksRun(in result: CleanOutcome) -> [MaintenanceTask] {
        var ran: [MaintenanceTask] = []
        for step in result.steps where step.skippedReason == nil {
            if step.id == PerformancePlan.adminTasksStepID {
                let attempted = selectedTasks.filter(\.needsPassword)
                if step.failures.contains(where: { $0.contains("cancelled") }) || step.failures.contains(where: { !$0.contains("failed:") }) {
                    continue
                }
                let failed = Set(step.failures.flatMap(PerformancePlan.failedTasks))
                ran += MaintenanceTask.allCases.filter { attempted.contains($0) && !failed.contains($0) }
            } else if step.failures.isEmpty, let task = MaintenanceTask.allCases.first(where: { PerformancePlan.stepID(for: $0) == step.id }) {
                ran.append(task)
            }
        }
        return ran
    }

    /// What to say under a step of the receipt, in place of the clean-up's wording. Nil keeps that wording.
    func receiptDetail(for step: StepOutcome) -> String? {
        if step.id == PerformancePlan.adminTasksStepID {
            guard let failure = step.failures.first else { return "Ran with your password." }
            if failure.contains("cancelled") { return "The password prompt was cancelled, so none of these ran." }
            let failed = PerformancePlan.failedTasks(in: failure)
            guard !failed.isEmpty else { return nil }
            return "\(PerformancePlan.titles(of: failed)) did not finish; the log has what the tool said. The rest ran."
        }
        guard step.failures.isEmpty else { return nil }
        if let task = MaintenanceTask.allCases.first(where: { PerformancePlan.stepID(for: $0) == step.id }) {
            switch task {
            case .purgeableSpace:
                return run.gained > 0 ? "macOS gave back \(ByteFormat.string(run.gained))." : "Ran. macOS gave back what it could; the figure settles over the next minutes."
            case .speedUpMail: return "Compacted. Mail rebuilds what it needs the next time it opens."
            case .reindexSpotlight: return "Spotlight is building a fresh index in the background."
            default: return "Ran."
            }
        }
        if step.id.hasPrefix("login/") { return "Taken off the Open at Login list. The app is still installed." }
        if step.id.hasPrefix("background/") {
            return step.method == .trash
                ? "Unloaded and moved to the Trash. Put Back returns it until the Trash is emptied."
                : "Unloaded and moved to the Trash with your password."
        }
        return nil
    }

    /// Back to the manager after a run, for whatever else is on the list.
    func manageMore() {
        guard phase == .done else { return }
        phase = .managing
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
    /// Fills the screen with made-up findings and opens the named part of it. See `PerformanceDemoData`.
    func showDemo(_ screen: String) {
        if screen == "scan" {
            startScan()
            return
        }
        checks = PerformanceDemoData.checks()
        loginItems = PerformanceDemoData.loginItems()
        backgroundItems = PerformanceDemoData.backgroundItems(home: home)
        selectedTasks = Set(recommended.map(\.task))
        scanned = Date()
        phase = .managing
        switch screen {
        case "intro":
            phase = .idle
        case "scanning":
            progress = "Reading the launch agents and daemons"
            phase = .scanning
        case "summary":
            phase = .summary
        case "login":
            section = .loginItems
            selectedLoginItems = Set(loginItems.prefix(1).map(\.id))
        case "background":
            section = .backgroundItems
            selectedBackgroundItems = Set(backgroundItems.prefix(2).map(\.id))
        case "review":
            showingReview = true
        case "running":
            runProgress = CleanProgress(fraction: 0.4, status: "Free Up Purgeable Space")
            phase = .running
        case "done":
            finish(PerformanceDemoData.outcome(for: plan), section: .maintenance, recordsRuns: false)
        default:
            break
        }
    }
    #endif
}
