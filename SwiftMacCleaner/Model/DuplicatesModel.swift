//
//  DuplicatesModel.swift
//  SwiftMacCleaner
//

import AppKit
import Observation
import SwiftUI

/// State behind the Duplicates screen: where to look, the groups of identical files that were found,
/// and whatever the user has ticked for removal. One copy in every group is always left unticked.
@Observable
final class DuplicatesModel {
    enum Phase {
        case idle, scanning, results, removing, done
    }

    enum Scope: String, CaseIterable, Identifiable {
        case home, folder

        var id: String { rawValue }
        var title: String {
            switch self {
            case .home: "Home Folder"
            case .folder: "One Folder"
            }
        }
    }

    enum Sort: String, CaseIterable, Identifiable {
        case space, size, copies, name

        var id: String { rawValue }
        var title: String {
            switch self {
            case .space: "Space to Get Back"
            case .size: "File Size"
            case .copies: "Number of Copies"
            case .name: "Name"
            }
        }
    }

    /// What a removal took away, which decides how the result is worded.
    struct Removal {
        var files = 0
        var size: Int64 = 0
        var leftOut = 0
    }

    let home: URL
    let settings: AppSettings
    /// Called after a removal, so the owner can refresh the disk figure and the offer to put things back.
    @ObservationIgnored var didRemove: (CleanOutcome) -> Void = { _ in }
    /// Called after a removal with what it did, for My Activity.
    @ObservationIgnored var didRecord: (ActivityRecord) -> Void = { _ in }

    var scope: Scope = .home
    /// The folder looked through when the scope is one folder.
    private(set) var folder: URL?
    var showingFolderPicker = false

    private(set) var phase: Phase = .idle
    private(set) var progress = DuplicateProgress()
    private(set) var groups: [DuplicateGroup] = []
    /// The last scan's figures. Its groups are kept in `groups`, which removals change.
    private(set) var scan = DuplicateScan()
    /// What was looked through, for the sentence that sums up the results.
    private(set) var scannedTitle = ""
    private(set) var selected: Set<String> = []
    private(set) var removeProgress = CleanProgress(fraction: 0, status: "")
    private(set) var outcome: CleanOutcome?
    private(set) var removal = Removal()

    /// The kind of file the list is narrowed to. Nil shows every kind.
    var kind: DuplicateKind?
    var sort: Sort = .space
    var search = ""
    var showingReview = false

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var scanned: Date?

    init(home: URL, settings: AppSettings) {
        self.home = home
        self.settings = settings
    }

    // MARK: Where to look

    /// The folders a scan looks through.
    var roots: [URL] {
        switch scope {
        case .home: [home]
        case .folder: folder.map { [$0] } ?? []
        }
    }

    var canScan: Bool { !roots.isEmpty }

    func choose(_ url: URL) {
        folder = url.standardizedFileURL
        scope = .folder
    }

    /// Why a chosen folder would give nothing: everything outside the home folder is left as it is.
    var folderNote: String? {
        guard scope == .folder, let folder else { return nil }
        let path = folder.resolvingSymlinksInPath().path
        let homePath = home.resolvingSymlinksInPath().path
        return path == homePath || path.hasPrefix(homePath + "/") ? nil
            : "This folder is outside your home folder, where this app removes nothing. Copies in it can only be listed as ones that stay."
    }

    // MARK: Scanning

    func start() {
        guard canScan else { return }
        task?.cancel()
        groups = []
        selected = []
        outcome = nil
        search = ""
        kind = nil
        showingReview = false
        progress = DuplicateProgress()
        scannedTitle = scope == .home ? "your home folder" : folder.map { "“\($0.lastPathComponent)”" } ?? ""
        phase = .scanning
        let roots = roots
        let safety = SafetyGuard(root: home, neverSuggest: settings.neverSuggest.map(\.path))
        task = Task { [home] in
            let found = await DuplicateScanner.scan(roots: roots, home: home, safety: safety) { progress in
                Task { @MainActor in
                    if self.phase == .scanning { self.progress = progress }
                }
            }
            guard !Task.isCancelled, let found else { return }
            scan = found
            groups = found.groups
            scanned = Date()
            phase = .results
        }
    }

    func stop() {
        task?.cancel()
        phase = .idle
    }

    /// Forgets the scan and goes back to choosing where to look.
    func reset() {
        task?.cancel()
        showingReview = false
        groups = []
        selected = []
        phase = .idle
    }

    // MARK: The list

    /// The most the groups can give back with one copy of each kept.
    var reclaimable: Int64 { groups.reduce(0) { $0 + $1.reclaimable } }

    func groups(of kind: DuplicateKind?) -> [DuplicateGroup] {
        kind.map { kind in groups.filter { $0.kind == kind } } ?? groups
    }

    /// The kinds that have at least one group, which are the only ones worth a row in the column.
    var kinds: [DuplicateKind] { DuplicateKind.allCases.filter { kind in groups.contains { $0.kind == kind } } }

    /// The groups the list shows: the chosen kind, narrowed by the search, in the chosen order.
    var visibleGroups: [DuplicateGroup] {
        let query = search.trimmingCharacters(in: .whitespaces)
        let shown = groups(of: kind).filter { group in
            query.isEmpty || group.files.contains { $0.url.path.localizedStandardContains(query) }
        }
        switch sort {
        // The scan gives them in this order already.
        case .space: return shown
        case .size: return shown.sorted { $0.size > $1.size }
        case .copies: return shown.sorted { ($0.files.count, $0.size) > ($1.files.count, $1.size) }
        case .name: return shown.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    // MARK: Selection

    func isSelected(_ file: DuplicateFile) -> Bool { selected.contains(file.id) }

    /// How many copies of a group are not ticked, the ones that have to stay included.
    func staying(in group: DuplicateGroup) -> Int { group.files.count { !selected.contains($0.id) } }

    /// Whether the file's tick box can be changed. A copy that has to stay cannot be ticked, and
    /// neither can the last copy left unticked: one always stays.
    func canToggle(_ file: DuplicateFile, in group: DuplicateGroup) -> Bool {
        !file.isLocked && (selected.contains(file.id) || staying(in: group) > 1)
    }

    func binding(for file: DuplicateFile, in group: DuplicateGroup) -> Binding<Bool> {
        Binding(
            get: { self.selected.contains(file.id) },
            set: { isOn in
                if !isOn {
                    self.selected.remove(file.id)
                } else if self.canToggle(file, in: group) {
                    self.selected.insert(file.id)
                }
            }
        )
    }

    /// One binding per copy a tidy-up would remove, for the tick box on a group's heading.
    func bindings(forExtrasOf group: DuplicateGroup) -> [Binding<Bool>] {
        group.extras.map { file in
            Binding(
                get: { self.selected.contains(file.id) },
                set: { isOn in
                    // Ticking the heading ticks exactly the extra copies, whatever was ticked in the group before.
                    if isOn { self.selected.subtract(group.files.map(\.id)) }
                    if isOn { self.selected.formUnion(group.extras.map(\.id)) } else { self.selected.remove(file.id) }
                }
            )
        }
    }

    /// Ticks every copy but the one most worth keeping, in each group the list shows.
    func selectExtras() {
        for group in visibleGroups {
            selected.subtract(group.files.map(\.id))
            selected.formUnion(group.extras.map(\.id))
        }
    }

    func selectNone() {
        selected = []
    }

    var selectedCount: Int { selected.count }

    /// What removing the ticked files would give back, with copies that share their space counted once.
    var selectedSize: Int64 { groups.reduce(0) { $0 + $1.freed(removing: selected) } }

    /// The ticked files that share their space with a copy that stays, so removing them gives nothing back.
    var selectedSharing: Int {
        groups.reduce(0) { total, group in
            let going = group.files.filter { selected.contains($0.id) }
            guard !going.isEmpty else { return total }
            let shares = group.shares(removing: going)
            return total + going.count { $0.sharesSpace && shares[$0.id] == 0 }
        }
    }

    // MARK: Removing

    /// What the confirmation shows. The plan that is carried out is made again then, with every file looked at once more.
    var plan: CleanPlan { DuplicatePlan.make(groups: groups, selection: selected).plan }

    func remove() {
        guard phase == .results else { return }
        let checked = DuplicatePlan.make(groups: groups, selection: selected, verifying: true)
        let before = groups
        let safety = SafetyGuard(root: home, neverSuggest: settings.neverSuggest.map(\.path))
        showingReview = false
        removeProgress = CleanProgress(fraction: 0, status: "Getting ready")
        phase = .removing
        Task {
            let result = await Cleaner.run(plan: checked.plan, safety: safety, scannedAt: scanned) { progress in
                Task { @MainActor in self.removeProgress = progress }
            }
            finish(DuplicatePlan.recording(checked.leftOut, in: result, groups: before))
        }
    }

    private func finish(_ result: CleanOutcome) {
        let removed = result.cleanedItemIDs
        removal = Removal(
            files: removed.count,
            size: groups.reduce(0) { $0 + $1.freed(removing: removed) },
            leftOut: result.steps.reduce(0) { $0 + $1.skippedItems.count + $1.failures.count }
        )
        groups = groups.compactMap { Self.without(removed, from: $0) }
        selected.subtract(removed)
        selected.formIntersection(groups.flatMap(\.files).map(\.id))
        outcome = result
        didRemove(result)
        didRecord(.duplicates(result, copies: removal.files, freed: removal.size))
        phase = .done
    }

    /// A group with the given files gone. Nil when fewer than two copies are left, or none of them may go.
    /// What the disk says about the copies that are left is read again: a clone whose twin has gone
    /// no longer shares its space.
    static func without(_ removed: Set<String>, from group: DuplicateGroup) -> DuplicateGroup? {
        guard group.files.contains(where: { removed.contains($0.id) }) else { return group }
        var group = group
        group.files.removeAll { removed.contains($0.id) }
        for index in group.files.indices {
            if let storage = FileStorage.read(group.files[index].url.path) { group.files[index].storage = storage }
        }
        return group.files.count > 1 && group.files.contains(where: { !$0.isLocked }) ? group : nil
    }

    /// Back to the list after a removal, or to the start when nothing is left on it.
    func showResults() {
        guard phase == .done else { return }
        phase = groups.isEmpty ? .idle : .results
    }

    // MARK: Never Suggest

    /// Leaves everything in the file's folder alone from now on: its copies there become ones that stay.
    func neverSuggest(folderOf file: DuplicateFile) {
        let folder = file.url.deletingLastPathComponent().standardizedFileURL
        settings.addNeverSuggest(path: folder.path, title: folder.lastPathComponent)
        let prefix = folder.path + "/"
        groups = groups.compactMap { group in
            guard group.files.contains(where: { $0.url.path.hasPrefix(prefix) }) else { return group }
            var group = group
            for index in group.files.indices where group.files[index].url.path.hasPrefix(prefix) && !group.files[index].isLocked {
                group.files[index].lockedReason = DuplicateScanner.lockedReason(for: "on your Never Suggest list")
                selected.remove(group.files[index].id)
            }
            // The copies that stay are listed first, as the scan lists them.
            group.files = group.files.filter(\.isLocked) + group.files.filter { !$0.isLocked }
            return group.files.contains(where: { !$0.isLocked }) ? group : nil
        }
    }

    /// The path with the home folder written as `~`.
    func displayPath(_ url: URL) -> String {
        let path = url.path
        let homePath = home.path
        guard path == homePath || path.hasPrefix(homePath + "/") else { return path }
        return "~" + path.dropFirst(homePath.count)
    }

    #if DEBUG
    /// Fills the screen with made-up groups and opens the named part of it. See `DuplicatesDemoData`.
    func showDemo(_ screen: String, folder: URL? = nil) {
        // `scan` is the one screen that is not made up: it looks through a real folder, which only reads.
        if screen == "scan" {
            if let folder { choose(folder) }
            start()
            return
        }
        groups = DuplicatesDemoData.groups()
        scan = DuplicateScan(groups: groups, filesSeen: 48_210, bytesRead: 3_400_000_000, cloudOnly: 12, duration: 6.4)
        scannedTitle = "your home folder"
        scanned = Date()
        phase = .results
        switch screen {
        case "intro":
            phase = .idle
        case "scanning":
            progress = DuplicateProgress(stage: .comparing, filesSeen: 48_210, toCompare: 412, compared: 157, bytesRead: 1_300_000_000,
                                         path: "/Users/demo/Movies/Exports/Harbour timelapse.mov")
            phase = .scanning
        case "review", "removing", "done":
            selectExtras()
            if screen == "review" {
                showingReview = true
            } else if screen == "removing" {
                removeProgress = CleanProgress(fraction: 0.4, status: "Images")
                phase = .removing
            } else {
                finish(DuplicatesDemoData.outcome(for: plan))
            }
        case "ticked":
            selectExtras()
        default:
            break
        }
    }

    /// Finishes a made-up removal of whatever is ticked, for a test that ticks by hand first.
    func finishDemoRemoval() {
        finish(DuplicatesDemoData.outcome(for: plan))
    }
    #endif
}
