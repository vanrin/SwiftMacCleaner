//
//  AppModel.swift
//  SwiftMacCleaner
//

import AppKit
import Observation
import SwiftUI
import UserNotifications

enum SidebarItem: Hashable {
    /// The overview: one scan that runs every part below and shows what each found, with one Run for all of it.
    case overview
    /// A clean-up with a scan of its own: System Clean Up, Developer Clean Up or Large old files.
    case group(AreaGroup)
    /// Largest Folders, which the overview leaves alone: it measures rather than finds.
    case space
    /// Duplicates, which the overview leaves alone too: reading files to compare them takes a while.
    case duplicates
    /// Applications: uninstalling, updates, leftovers and installers, with a scan of its own.
    case apps
    /// Performance: maintenance tasks, login items and background items, with a scan of its own too.
    case performance
    /// Protection: how this Mac's own defences are set. Its check only reads, and Run has nothing to do there.
    case protection

    var title: String {
        switch self {
        case .overview: "Overview"
        case .group(let group): group.title
        case .space: "Largest Folders"
        case .duplicates: "Duplicates"
        case .apps: "Applications"
        case .performance: "Performance"
        case .protection: "Protection"
        }
    }

    /// The parts the overview's scan runs and its tiles stand for, in the order they are shown.
    static let parts = AreaGroup.allCases.map(SidebarItem.group) + [.protection, .performance, .apps]
}

/// Which apps are running, asked of the workspace. Kept apart so a non-UI caller can ask too.
nonisolated enum RunningApps {
    static func isRunning(bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }
}

@Observable
final class AppModel {
    /// Where the overview is: its scan runs every part, its results show them side by side, and its run
    /// goes through the ticked ones in turn.
    enum OverviewPhase {
        case home, scanning, results, running, done
    }

    let settings: AppSettings
    /// The folder everything is cleaned inside. Tests pass a temporary folder.
    let home: URL
    /// One clean-up per group, in the order the sidebar lists them.
    let cleanUps: [CleanUpModel]
    let space: SpaceModel
    let duplicates: DuplicatesModel
    let apps: AppsModel
    let performance: PerformanceModel
    let protection: ProtectionModel
    /// The processor, memory and battery readings on the menu bar popover.
    let vitals: VitalsModel
    /// Which apps are open, shared by every clean-up: a cache waits while the app that keeps it is open.
    let openApps = OpenApps()
    /// Whether macOS opens the app at login.
    let openAtLogin: OpenAtLogin

    private(set) var disk = DiskInfo.current()
    /// Items from the last clean that are still in the Trash and can be put back.
    private(set) var putBackPending: PutBack.Manifest?
    private(set) var putBackMessage: String?

    var sidebarSelection: SidebarItem = .overview
    /// Areas switched off on the home screen. Stored this way so a new area starts switched on.
    var disabledAreas: Set<Area> {
        didSet { UserDefaults.standard.set(disabledAreas.map(\.rawValue), forKey: "disabledAreas") }
    }
    /// Developer areas switched on although nothing of theirs was found on this Mac.
    var forcedAreas: Set<Area> {
        didSet { UserDefaults.standard.set(forcedAreas.map(\.rawValue), forKey: "forcedAreas") }
    }
    /// The tools and kinds of project found on this Mac, which decide the developer areas worth showing.
    private(set) var stack = DetectedStack()

    // The overview's own state. What each part found lives in that part.
    private(set) var overviewPhase: OverviewPhase = .home
    /// The parts Run acts on: the tick boxes on the overview's tiles.
    var included: Set<SidebarItem> = []
    var showingOverviewReview = false
    /// The receipts of the last run, as one.
    private(set) var overviewOutcome: CleanOutcome?
    /// The part being run right now, and how far the run is, for its progress.
    private(set) var runningPart: SidebarItem?
    private(set) var runDone = 0
    private(set) var runTotal = 0
    /// Set by Scan and Clean: when the scan ends, open the confirmation over the Smart selection.
    @ObservationIgnored private var reviewWhenScanned = false
    /// Set by the weekly check: say what the scan found instead of showing it.
    @ObservationIgnored private var notifyWhenScanned = false

    /// What the project folders were last seen to hold. Reading them takes longer than the rest of the stack.
    @ObservationIgnored private var projectKinds: [ProjectKind] = []
    @ObservationIgnored private var stackTask: Task<Void, Never>?
    /// Launched with made-up results: the weekly check must not start a real scan over them.
    @ObservationIgnored private var isDemo = false
    /// Set by `--demo menubar`: the main window shows the menu bar popover in place of the app.
    private(set) var showsMenuBarDemo = false

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser, settings: AppSettings = AppSettings(),
         openAtLogin: OpenAtLogin = OpenAtLogin()) {
        self.home = home
        self.settings = settings
        self.openAtLogin = openAtLogin
        let openApps = openApps
        cleanUps = AreaGroup.allCases.map { CleanUpModel(home: home, settings: settings, group: $0, openApps: openApps) }
        space = SpaceModel(home: home)
        duplicates = DuplicatesModel(home: home, settings: settings)
        apps = AppsModel(home: home, settings: settings)
        performance = PerformanceModel(home: home, settings: settings)
        protection = ProtectionModel(settings: settings)
        vitals = VitalsModel(settings: settings)
        disabledAreas = Area.stored(forKey: "disabledAreas")
        forcedAreas = Area.stored(forKey: "forcedAreas")
        putBackPending = PutBack.pending(home: home)
        updateStack()
        for cleanUp in cleanUps {
            cleanUp.didScan = { [weak self] in self?.partDidScan() }
            cleanUp.didClean = { [weak self] outcome in self?.absorb(outcome) }
        }
        apps.didScan = { [weak self] in self?.partDidScan() }
        apps.didRemove = { [weak self] outcome in self?.absorb(outcome) }
        duplicates.didRemove = { [weak self] outcome in self?.absorb(outcome) }
        performance.didScan = { [weak self] in self?.partDidScan() }
        performance.didRun = { [weak self] outcome in self?.absorb(outcome) }
        protection.didScan = { [weak self] in self?.partDidScan() }
        vitals.start()
        #if DEBUG
        if let flag = CommandLine.arguments.firstIndex(of: "--demo") {
            isDemo = true
            openApps.list = { DemoData.openApps }
            // `--vitals <state>` after any demo puts the menu bar's readings in that state: see `VitalsDemoData`.
            var arguments = Array(CommandLine.arguments.dropFirst(flag + 1))
            var state = "normal"
            if let option = arguments.firstIndex(of: "--vitals") {
                state = arguments.dropFirst(option + 1).first ?? state
                arguments.removeSubrange(option...)
            }
            vitals.standIn = VitalsDemoData.vitals(state)
            loadDemo(screen: arguments.first ?? "results", arguments: Array(arguments.dropFirst()))
        }
        #endif
    }

    func cleanUp(_ group: AreaGroup) -> CleanUpModel {
        cleanUps[AreaGroup.allCases.firstIndex(of: group) ?? 0]
    }

    /// The areas a scan looks at, across every clean-up.
    var enabledAreas: Set<Area> { Set(Area.cleanUp.filter(isScanned)) }

    // MARK: Stack

    /// Whether a scan looks at the area: one that applies to this Mac unless it was switched off,
    /// any other only when it was switched on regardless.
    func isScanned(_ area: Area) -> Bool {
        stack.scans(area, disabled: disabledAreas, forced: forcedAreas)
    }

    /// Whether the area is worth listing: it applies to this Mac, or was switched on regardless.
    func isListed(_ area: Area) -> Bool { stack.applies(area) || forcedAreas.contains(area) }

    var listedAreas: [Area] { Area.cleanUp.filter(isListed) }

    /// Whether the area has a place in the window: any that is listed, and any the last scan looked at.
    func isShown(_ area: Area) -> Bool {
        guard let group = area.group else { return false }
        return isListed(area) || cleanUp(group).areaState(for: area) != .idle
    }

    /// Looks again at which tools this Mac has. The home folder is checked on the spot; the project
    /// folders take a moment longer and are read in the background.
    func refreshStack() {
        updateStack()
        let roots = settings.projectRoots.map { URL(fileURLWithPath: $0, isDirectory: true) }
        stackTask?.cancel()
        stackTask = Task { [home] in
            let kinds = await StackDetector.projectKinds(in: roots, home: home)
            guard !Task.isCancelled else { return }
            projectKinds = kinds
            updateStack()
        }
    }

    private func updateStack() {
        let detected = StackDetector.detect(home: home)
            .adding(projectKinds, hasProjectFolders: !settings.projectRoots.isEmpty)
        if detected != stack { stack = detected }
    }

    // MARK: Groups

    /// The areas with a place under a clean-up's entry: those that apply to this Mac, and any its last
    /// scan looked at. For Developer Clean Up that is the areas this Mac has tools for.
    func areas(in group: AreaGroup) -> [Area] { group.areas.filter(isShown) }

    /// The parts the overview shows, which the sidebar lists under it in the same order: every clean-up
    /// worth a place, then Performance and Applications. A clean-up none of whose areas apply to this
    /// Mac is left out, which is Developer Clean Up on a Mac without developer tools.
    var overviewParts: [SidebarItem] {
        SidebarItem.parts.filter { part in
            if case .group(let group) = part { !areas(in: group).isEmpty } else { true }
        }
    }

    // MARK: Scanning

    /// Runs one clean-up's scan over the areas of its group this Mac has and the user has left on.
    func scan(_ group: AreaGroup) {
        refreshStack()
        cleanUp(group).startScan(areas: group.areas.filter(isScanned))
    }

    /// The overview's scan: every part at once.
    func startScan() {
        notifyWhenScanned = false
        beginOverviewScan()
    }

    /// Scans everything and goes straight to the confirmation, with the Smart selection ticked.
    func scanAndClean() {
        notifyWhenScanned = false
        beginOverviewScan(thenReview: true)
    }

    private func beginOverviewScan(thenReview: Bool = false) {
        reviewWhenScanned = thenReview
        refreshStack()
        sidebarSelection = .overview
        showingOverviewReview = false
        overviewOutcome = nil
        overviewPhase = .scanning
        for group in AreaGroup.allCases {
            cleanUp(group).startScan(areas: group.areas.filter(isScanned))
        }
        apps.startScan()
        performance.startScan()
        protection.startScan()
        partDidScan()
    }

    /// Whether the part's own scan is under way.
    func isScanning(_ part: SidebarItem) -> Bool {
        switch part {
        case .group(let group): cleanUp(group).phase == .scanning
        case .apps: apps.phase == .scanning
        case .performance: performance.phase == .scanning
        case .protection: protection.phase == .scanning
        case .duplicates: duplicates.phase == .scanning
        case .overview, .space: false
        }
    }

    /// Whether the part has results to show, from the overview's scan or one of its own.
    func hasResults(_ part: SidebarItem) -> Bool {
        switch part {
        case .group(let group): cleanUp(group).phase != .home && cleanUp(group).phase != .scanning
        case .apps: apps.phase != .idle && apps.phase != .scanning
        case .performance: performance.phase != .idle && performance.phase != .scanning
        case .protection: protection.phase == .results
        case .overview, .space, .duplicates: false
        }
    }

    /// Whether Run would do anything for the part: ticked items in a clean-up, or recommended tasks.
    /// Applications never acts on its own: apps are only ever removed by hand, and updates by the store.
    /// Protection never does either: its settings are the user's to change.
    func hasWork(_ part: SidebarItem) -> Bool {
        switch part {
        case .group(let group):
            let cleanUp = cleanUp(group)
            return cleanUp.phase == .results && (cleanUp.selectedSize > 0 || cleanUp.selectionHasUnknownSize)
        case .performance:
            return performance.phase != .idle && performance.phase != .scanning && !performance.recommended.isEmpty
        case .apps, .protection, .overview, .space, .duplicates:
            return false
        }
    }

    /// The parts of the overview's scan still under way, and how many it ran.
    var scanningParts: [SidebarItem] { overviewParts.filter(isScanning) }
    var scannedPartCount: Int { overviewParts.count { hasResults($0) || isScanning($0) } }

    /// What the clean-ups have found so far, together.
    var foundSize: Int64 { cleanUps.reduce(0) { $0 + $1.foundSize } }
    var hasFindings: Bool { cleanUps.contains { !$0.findings.isEmpty } }
    /// What the menu bar offers: the Smart selection across every clean-up.
    var smartSize: Int64 { cleanUps.reduce(0) { $0 + $1.smartSize } }
    /// What is ticked across every clean-up, whether or not Run is set to act on it.
    var selectedSize: Int64 { cleanUps.reduce(0) { $0 + $1.selectedSize } }
    /// Folders macOS would not let the last scans read, across every clean-up.
    var unreadableFolders: [String] {
        var seen: [String] = []
        for folder in cleanUps.flatMap(\.unreadableFolders) where !seen.contains(folder) { seen.append(folder) }
        return seen
    }

    /// The areas with the most found across every clean-up, largest first.
    func largestAreas(_ count: Int) -> [(area: Area, size: Int64)] {
        cleanUps.flatMap { $0.largestAreas(count) }.sorted { $0.size > $1.size }.prefix(count).map { $0 }
    }

    /// Called by every part when its scan ends. The overview's scan is done when the last of them is.
    private func partDidScan() {
        disk = DiskInfo.current()
        guard overviewPhase == .scanning, scanningParts.isEmpty else { return }
        finishOverviewScan()
    }

    private func finishOverviewScan() {
        overviewPhase = overviewParts.contains(where: hasResults) ? .results : .home
        settings.lastScanDate = Date()
        included = Set(overviewParts.filter(hasWork))
        if notifyWhenScanned {
            notifyWhenScanned = false
            if settings.weeklyCheckCleans, runSize > 0 {
                run(unattended: true)
            } else {
                notifyAboutScan()
            }
        }
        if reviewWhenScanned {
            reviewWhenScanned = false
            reviewSmart()
        }
    }

    /// Stops every part early and shows whatever has been found so far.
    func stopScan() {
        guard overviewPhase == .scanning else { return }
        // Set first, so the parts' callbacks do not finish the scan a second time.
        overviewPhase = .results
        for cleanUp in cleanUps where cleanUp.phase == .scanning { cleanUp.stopScan() }
        if apps.phase == .scanning { apps.stop() }
        if performance.phase == .scanning { performance.stop() }
        if protection.phase == .scanning { protection.stop() }
        finishOverviewScan()
    }

    // MARK: Running

    /// What Run would do: the ticked items of every ticked clean-up, and the recommended tasks when
    /// Performance is ticked.
    var runPlan: CleanPlan {
        var plan = CleanPlan()
        for cleanUp in cleanUps where included.contains(.group(cleanUp.group)) {
            plan.steps += cleanUp.plan(in: nil).steps
        }
        if included.contains(.performance), hasWork(.performance) {
            plan.steps += performance.recommendedPlan.steps
        }
        return plan
    }

    /// Steps of the run that have to wait because what owns them is open, with the reason.
    var runBlockedSteps: [String: String] {
        var blocked: [String: String] = [:]
        for cleanUp in cleanUps where included.contains(.group(cleanUp.group)) {
            blocked.merge(cleanUp.blockedSteps(in: cleanUp.plan(in: nil))) { first, _ in first }
        }
        if included.contains(.performance) {
            blocked.merge(performance.blockedSteps(in: performance.recommendedPlan)) { first, _ in first }
        }
        return blocked
    }

    /// How much the run frees: what is ticked in the ticked clean-ups, less what waits for something
    /// that is open. Tasks free nothing that is measured. The confirmation shows the same figure.
    var runSize: Int64 {
        cleanUps.filter { included.contains(.group($0.group)) }.reduce(0) { $0 + $1.cleanableSize() }
    }

    /// How much of what Run would take waits for something that is open, and the apps it waits for.
    var runWaitingSize: Int64 {
        cleanUps.filter { included.contains(.group($0.group)) }.reduce(0) { $0 + $1.waitingSize() }
    }

    /// The items of the run that wait because an app that keeps them is open, with the sentence each
    /// gets on the receipt.
    var runWaitingItems: [String: String] {
        var waiting: [String: String] = [:]
        for cleanUp in cleanUps where included.contains(.group(cleanUp.group)) {
            waiting.merge(cleanUp.waitingReasons()) { first, _ in first }
        }
        return waiting
    }

    /// The open apps the run waits for, across every ticked clean-up, the largest first.
    var runBlockingApps: [BlockingApp] {
        var blocking: [String: BlockingApp] = [:]
        for cleanUp in cleanUps where included.contains(.group(cleanUp.group)) {
            for entry in cleanUp.blockingApps() {
                blocking[entry.id, default: BlockingApp(app: entry.app, size: 0)].size += entry.size
            }
        }
        return blocking.values.sorted { ($0.size, $1.app.name) > ($1.size, $0.app.name) }
    }

    var runHasUnknownSize: Bool {
        cleanUps.contains { included.contains(.group($0.group)) && $0.selectionHasUnknownSize }
    }

    func reviewRun() {
        openApps.refresh()
        for cleanUp in cleanUps where cleanUp.phase == .results { cleanUp.refreshActiveChecks() }
        showingOverviewReview = true
    }

    /// Goes through the ticked parts in turn: each clean-up cleans what is ticked in it, then Performance
    /// runs its recommended tasks. Every part keeps its own receipt; the overview shows them as one.
    ///
    /// `unattended` is the clean after the weekly check, which nobody confirmed and nobody is watching:
    /// it leaves out the maintenance tasks and every step that would ask for a password, and says what
    /// it did in a notification.
    func run(unattended: Bool = false) {
        guard overviewPhase == .results, !runPlan.isEmpty else { return }
        showingOverviewReview = false
        let cleanUps = cleanUps.filter { included.contains(.group($0.group)) && !$0.plan(in: nil).isEmpty }
        let runsTasks = !unattended && included.contains(.performance) && hasWork(.performance)
        runTotal = cleanUps.count + (runsTasks ? 1 : 0)
        runDone = 0
        overviewPhase = .running
        Task {
            var outcomes: [CleanOutcome] = []
            for cleanUp in cleanUps {
                runningPart = .group(cleanUp.group)
                if let outcome = await cleanUp.runClean(area: nil, unattended: unattended) { outcomes.append(outcome) }
                runDone += 1
            }
            if runsTasks {
                runningPart = .performance
                if let outcome = await performance.performRecommended() { outcomes.append(outcome) }
                runDone += 1
            }
            runningPart = nil
            overviewOutcome = CleanOutcome.merged(outcomes)
            sidebarSelection = .overview
            overviewPhase = overviewOutcome == nil ? .results : .done
            if unattended {
                // When everything ticked needed a password, nothing was cleaned and there is only the scan to report.
                if let overviewOutcome { notifyAboutClean(overviewOutcome) } else { notifyAboutScan() }
            }
        }
    }

    /// How far the run is: the parts done, and how far the one under way is.
    var runProgress: CleanProgress {
        guard runTotal > 0 else { return CleanProgress(fraction: 0, status: "Getting ready") }
        let current: CleanProgress? = switch runningPart {
        case .group(let group): cleanUp(group).cleanProgress
        case .performance: performance.runProgress
        default: nil
        }
        let fraction = (Double(runDone) + (current?.fraction ?? 0)) / Double(runTotal)
        let status = runningPart.map { part in
            current.map { "\(part.title): \($0.status)" } ?? part.title
        } ?? "Finishing"
        return CleanProgress(fraction: min(fraction, 1), status: status)
    }

    /// Leaves the "done" screen for what is still on the list.
    func showOverviewResults() {
        overviewPhase = overviewParts.contains(where: hasResults) ? .results : .home
    }

    /// Leaves what the overview's scan showed and goes back to its opening screen. Each part keeps
    /// what it found, until it is scanned again or started over itself.
    func startOver() {
        guard overviewPhase == .results || overviewPhase == .done else { return }
        showingOverviewReview = false
        overviewOutcome = nil
        overviewPhase = .home
    }

    /// The menu bar's one-click path: put the ticks back to the Smart selection from the last scans
    /// and confirm, or scan first. Results from a part's own scan count: the overview needs no scan of
    /// its own for this.
    func cleanSmart() {
        if cleanUps.contains(where: { $0.phase == .results || $0.phase == .done }) {
            sidebarSelection = .overview
            reviewSmart()
        } else {
            scanAndClean()
        }
    }

    /// Puts every clean-up's ticks back to the Smart selection, leaves the tasks out, and opens the
    /// overview's confirmation.
    func reviewSmart() {
        overviewPhase = .results
        for cleanUp in cleanUps { cleanUp.selectSmart() }
        included = Set(AreaGroup.allCases.map(SidebarItem.group).filter(hasWork))
        showingOverviewReview = runSize > 0 || runHasUnknownSize
    }

    /// Sets the ticks of every clean-up that has results to what the preset stands for, and has Run
    /// act on each clean-up that then has something ticked. The tick on Performance is left as it is.
    func select(_ preset: SelectionPreset) {
        for cleanUp in cleanUps where cleanUp.phase == .results { cleanUp.select(preset) }
        let groups = Set(AreaGroup.allCases.map(SidebarItem.group))
        included = included.subtracting(groups).union(groups.filter(hasWork))
    }

    /// Switches a kind of thing in or out of Smart selection. A clean-up whose ticks were the Smart
    /// selection follows at once; ticks set by hand are left as they are.
    func setSmart(_ kind: SmartKind, isOn: Bool) {
        let following = cleanUps.filter { $0.phase == .results && $0.preset() == .smart }
        if isOn { settings.smartKinds.insert(kind) } else { settings.smartKinds.remove(kind) }
        for cleanUp in following { cleanUp.select(.smart) }
        let groups = Set(following.map { SidebarItem.group($0.group) })
        included = included.subtracting(groups).union(groups.filter(hasWork))
    }

    /// The preset every clean-up's ticks amount to, or nil when they differ or were set by hand.
    var preset: SelectionPreset? {
        let presets = Set(cleanUps.filter { $0.phase == .results && !$0.findings.isEmpty }.map { $0.preset() })
        return presets.count == 1 ? presets.first ?? nil : nil
    }

    // MARK: Background check

    static let weeklyInterval: TimeInterval = 7 * 86_400

    @ObservationIgnored private var checkTimer: Timer?

    /// How long after a launch at login the first check waits, while everything else on the Mac starts up.
    static let loginQuietTime: TimeInterval = 300

    /// Keeps the disk figure fresh and, once a week, scans on its own while the app sits idle. The
    /// first look is taken at once, or after `delay` when the Mac has better things to do just then.
    func startBackgroundChecks(after delay: TimeInterval = 0) {
        guard checkTimer == nil else { return }
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.backgroundTick() }
        }
        guard delay > 0 else { return backgroundTick() }
        Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.backgroundTick() }
        }
    }

    func backgroundTick() {
        disk = DiskInfo.current()
        refreshStack()
        for cleanUp in cleanUps where cleanUp.phase == .results {
            cleanUp.refreshActiveChecks()
        }
        guard settings.weeklyCheck, !isDemo, overviewPhase == .home, !overviewParts.contains(where: isScanning),
              isWeeklyCheckDue else { return }
        notifyWhenScanned = true
        beginOverviewScan()
    }

    var isWeeklyCheckDue: Bool {
        guard let last = settings.lastScanDate else { return true }
        return Date().timeIntervalSince(last) >= Self.weeklyInterval
    }

    private func notifyAboutScan() {
        let smart = smartSize
        let found = foundSize
        notify(
            title: smart > 0 ? "\(ByteFormat.string(smart)) ready to clean" : "Your disk is in good shape",
            body: smart > 0
                ? "\(ByteFormat.string(found)) found in the weekly check. Open SwiftMacCleaner to review and clean."
                : found > 0 ? "The weekly check found \(ByteFormat.string(found)), none of it in the Smart selection."
                : "The weekly check found nothing worth removing."
        )
    }

    /// Says what the clean after the weekly check did, since nobody was there to see it.
    private func notifyAboutClean(_ outcome: CleanOutcome) {
        let left = runPlan.steps.count { $0.method.needsPassword }
        var body = "The weekly check cleaned the Smart selection. Open SwiftMacCleaner for the receipt."
        if left > 0 { body += " \(left == 1 ? "One group needs" : "\(left) groups need") your password and stayed." }
        notify(title: "\(ByteFormat.string(outcome.reclaimed)) freed", body: body)
    }

    private func notify(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            center.add(UNNotificationRequest(identifier: "weekly-check", content: content, trigger: nil))
        }
    }

    // MARK: Selection

    func binding(for area: Area) -> Binding<Bool> {
        Binding(
            get: { self.isScanned(area) },
            set: { isOn in
                // An area this Mac has no use for is remembered when switched on; any other, when switched off.
                if !self.stack.applies(area) {
                    if isOn { self.forcedAreas.insert(area) } else { self.forcedAreas.remove(area) }
                } else if isOn {
                    self.disabledAreas.remove(area)
                } else {
                    self.disabledAreas.insert(area)
                }
            }
        )
    }

    /// Whether Run acts on the part, as a binding for the tick box on its tile.
    func inclusion(of part: SidebarItem) -> Binding<Bool> {
        Binding(
            get: { self.included.contains(part) },
            set: { isOn in
                if isOn { self.included.insert(part) } else { self.included.remove(part) }
            }
        )
    }

    // MARK: Navigation

    /// Every entry leads somewhere at any time: each part has its own opening screen.
    func select(_ item: SidebarItem) {
        sidebarSelection = item
    }

    func isRunning(bundleID: String) -> Bool { RunningApps.isRunning(bundleID: bundleID) }

    /// Where the menu bar's Free Up Memory leads: Performance, with that one task ticked and the
    /// confirmation open over it. The task asks for the password, so it is never run from the menu itself.
    func freeUpMemory() {
        sidebarSelection = .performance
        performance.review(.freeMemory)
    }

    // MARK: Put Back

    /// Takes in what a clean-up, Applications or Performance removed: the Trash items join the offer
    /// to put things back.
    private func absorb(_ outcome: CleanOutcome) {
        PutBack.save(outcome, home: home)
        putBackPending = PutBack.pending(home: home)
        putBackMessage = nil
        disk = DiskInfo.current()
    }

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

    func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }

    func copyRunScript() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(runPlan.shellScript(), forType: .string)
    }

    /// The app can only see its own container while App Sandbox is on.
    var isSandboxed: Bool { ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil }

    /// Whether macOS lets the app read protected folders. There is no API to ask, so the check
    /// tries to open something that only Full Disk Access can reach. Several places are named
    /// because they move: macOS 27 no longer keeps a privacy database in the home folder, and
    /// probing that one alone said "off" whatever the setting was. None of these makes macOS ask.
    var hasFullDiskAccess: Bool {
        Files.firstPresentOpens([
            home.appending(path: "Library/Safari"),
            home.appending(path: "Library/Mail"),
            home.appending(path: ".Trash"),
            URL(filePath: "/Library/Application Support/com.apple.TCC/TCC.db"),
        ])
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

    // MARK: Demo

    #if DEBUG
    /// Fills the app with made-up results and opens the named screen. See `DemoData`.
    private func loadDemo(screen: String, arguments: [String]) {
        switch screen {
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
        case "duplicates":
            // `--demo duplicates [intro|scanning|results|ticked|review|removing|done]`, or `scan <folder>`
            sidebarSelection = .duplicates
            duplicates.showDemo(arguments.first ?? "results",
                                folder: arguments.dropFirst().first.map { URL(fileURLWithPath: $0, isDirectory: true) })
            if let trashed = duplicates.outcome?.trashed, !trashed.isEmpty {
                putBackPending = PutBack.Manifest(date: Date(), items: trashed)
            }
        case "apps":
            // `--demo apps [intro|scanning|summary|manager|updater|leftovers|review|removing|done]`
            sidebarSelection = .apps
            apps.showDemo(arguments.first ?? "manager")
            if let trashed = apps.outcome?.trashed, !trashed.isEmpty {
                putBackPending = PutBack.Manifest(date: Date(), items: trashed)
            }
        case "performance":
            // `--demo performance [intro|scanning|summary|manager|login|background|review|running|done]`
            sidebarSelection = .performance
            performance.showDemo(arguments.first ?? "summary")
        case "protection":
            // `--demo protection [intro|scanning|results|fine|scan]`
            sidebarSelection = .protection
            protection.showDemo(arguments.first ?? "results")
        case "menubar":
            // `--demo menubar [cpu|memory|battery]`: the menu bar popover in the window, with that reading's
            // details open beside it. `--vitals <state>` after it picks the state, as for any demo.
            showsMenuBarDemo = true
            if let kind = arguments.first.flatMap(VitalKind.init(rawValue:)) { vitals.toggle(kind) }
        case "system", "developer", "largeFiles":
            // `--demo <group> [intro|scanning|summary|quiet|manager|review|cleaning|done|scan]`
            guard let group = AreaGroup(rawValue: screen) else { return }
            sidebarSelection = .group(group)
            loadDemo(screen: arguments.first ?? "summary", into: cleanUp(group))
        case "home":
            break
        case "scanning":
            // Two parts are done, two are under way, and the clean-ups say so area by area.
            loadDemo(screen: "summary", into: cleanUp(.system))
            loadDemo(screen: "scanning", into: cleanUp(.developer))
            loadDemo(screen: "queued", into: cleanUp(.largeFiles))
            apps.showDemo("scanning")
            performance.showDemo("summary")
            protection.showDemo("results")
            overviewPhase = .scanning
        case "results", "review", "running", "done":
            for cleanUp in cleanUps { loadDemo(screen: "summary", into: cleanUp) }
            apps.showDemo("summary")
            performance.showDemo("summary")
            protection.showDemo("results")
            included = Set(overviewParts.filter(hasWork))
            overviewPhase = .results
            switch screen {
            case "review":
                showingOverviewReview = true
            case "running":
                loadDemo(screen: "done", into: cleanUp(.system))
                loadDemo(screen: "cleaning", into: cleanUp(.developer))
                runningPart = .group(.developer)
                runDone = 1
                runTotal = 4
                overviewPhase = .running
            case "done":
                // One part after another, each starting from the free space the one before left.
                var free = disk.free
                var outcomes: [CleanOutcome] = []
                for cleanUp in cleanUps {
                    let result = DemoData.outcome(for: cleanUp.findings, freeBefore: free)
                    free = result.freeAfter
                    cleanUp.show(outcome: result)
                    outcomes.append(result)
                }
                disk.free = free
                overviewOutcome = CleanOutcome.merged(outcomes)
                let trashed = outcomes.flatMap(\.trashed)
                if !trashed.isEmpty, let started = outcomes.first?.started {
                    putBackPending = PutBack.Manifest(date: started, items: trashed)
                }
                overviewPhase = .done
            default:
                break
            }
        default:
            // Any area of the clean-up by its raw name, such as `xcode`, `projects` or `packageCaches`:
            // its clean-up's manager, open on that area.
            guard let area = Area(rawValue: screen), let group = area.group else { return }
            sidebarSelection = .group(group)
            loadDemo(screen: "manager", into: cleanUp(group))
            cleanUp(group).openArea = area
        }
    }

    /// The screens every clean-up has, with the parts of them that are the app's to set.
    private func loadDemo(screen: String, into cleanUp: CleanUpModel) {
        cleanUp.showDemo(screen)
        if screen == "done" {
            let result = DemoData.outcome(for: cleanUp.findings, freeBefore: disk.free)
            disk.free = result.freeAfter
            cleanUp.show(outcome: result)
            if !result.trashed.isEmpty {
                putBackPending = PutBack.Manifest(date: result.started, items: result.trashed)
            }
        }
    }
    #endif
}

nonisolated extension CleanOutcome {
    /// Several receipts as one, for a run that went through more than one part: every step in order,
    /// the free space from before the first to after the last, and the first part's log.
    static func merged(_ outcomes: [CleanOutcome]) -> CleanOutcome? {
        guard let first = outcomes.first, let last = outcomes.last else { return nil }
        return CleanOutcome(
            steps: outcomes.flatMap(\.steps),
            freeBefore: first.freeBefore,
            freeAfter: last.freeAfter,
            trashedSize: outcomes.reduce(0) { $0 + $1.trashedSize },
            duration: outcomes.reduce(0) { $0 + $1.duration },
            logURL: outcomes.compactMap(\.logURL).first,
            started: first.started
        )
    }
}
