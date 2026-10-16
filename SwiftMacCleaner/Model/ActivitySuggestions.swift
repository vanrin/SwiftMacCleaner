//
//  ActivitySuggestions.swift
//  SwiftMacCleaner
//

import Foundation

/// Something worth doing next, as My Activity suggests it from what the app knows right now: what the
/// last scans found waiting, and how long it has been since a part was looked at or cleaned.
struct ActivitySuggestion: Identifiable {
    var id: String
    var item: SidebarItem
    var title: String
    var detail: String
    /// The button's word: "Review" leads to what was found, "Scan" starts a scan.
    var action: String
    /// The same for VoiceOver, which reads the button alone.
    var actionLabel: String
    var perform: () -> Void
}

extension AppModel {
    /// A full scan older than this is worth suggesting again.
    static let scanSuggestionAge: TimeInterval = weeklyInterval
    /// A clean-up that has not cleaned anything for this long is worth a fresh look.
    static let cleanSuggestionAge: TimeInterval = 14 * 86_400

    /// Up to three things worth doing next, the most pressing first.
    func suggestions(now: Date = Date()) -> [ActivitySuggestion] {
        var suggestions: [ActivitySuggestion] = []
        let lastScan = settings.lastScanDate
        if lastScan == nil, activity.isEmpty {
            suggestions.append(ActivitySuggestion(
                id: "first-scan", item: .overview, title: "Run a first scan",
                detail: "One scan looks at every part and ticks what is worth cleaning",
                action: "Scan", actionLabel: "Scan \(disk.name)", perform: { [weak self] in self?.scanEverything() }))
        }
        if disk.isLow {
            suggestions.append(ActivitySuggestion(
                id: "low", item: .overview, title: "\(disk.name) is running low",
                detail: "\(ByteFormat.string(disk.free)) free of \(ByteFormat.string(disk.capacity))",
                action: "Scan", actionLabel: "Scan \(disk.name)", perform: { [weak self] in self?.scanEverything() }))
        }
        if hasResults(.performance), !performance.recommended.isEmpty {
            let tasks = performance.recommended.map(\.task.title)
            suggestions.append(ActivitySuggestion(
                id: "tasks", item: .performance,
                title: "\(tasks.count) maintenance \(tasks.count == 1 ? "task" : "tasks") due",
                detail: ListFormat.string(tasks), action: "Review", actionLabel: "Review the maintenance tasks in Performance",
                perform: { [weak self] in self?.select(.performance) }))
        }
        if hasResults(.apps), !apps.updates.isEmpty {
            let names = apps.updates.compactMap { update in apps.apps.first { $0.id == update.id }?.name }
            let shown = names.count > 2 ? Array(names.prefix(1)) + ["\(names.count - 1) more"] : names
            suggestions.append(ActivitySuggestion(
                id: "updates", item: .apps,
                title: "\(apps.updates.count) app \(apps.updates.count == 1 ? "update" : "updates") to install",
                detail: ListFormat.string(shown), action: "Review", actionLabel: "Review the updates in Applications",
                perform: { [weak self] in self?.select(.apps) }))
        }
        if let lastScan, now.timeIntervalSince(lastScan) >= Self.scanSuggestionAge, overviewPhase == .home {
            suggestions.append(ActivitySuggestion(
                id: "scan", item: .overview, title: "\(Self.days(from: lastScan, to: now)) days since the last full scan",
                detail: "One scan looks at every part and ticks what is worth cleaning",
                action: "Scan", actionLabel: "Scan \(disk.name)", perform: { [weak self] in self?.scanEverything() }))
        }
        for group in AreaGroup.allCases where overviewParts.contains(.group(group)) && cleanUp(group).phase == .home {
            guard let last = activity.lastClean(of: ActivityRecord.Part(group)),
                  now.timeIntervalSince(last) >= Self.cleanSuggestionAge else { continue }
            suggestions.append(ActivitySuggestion(
                id: "clean-\(group.rawValue)", item: .group(group),
                title: "\(group.title): \(Self.days(from: last, to: now)) days since a clean",
                detail: "Last cleaned on \(last.formatted(.dateTime.day().month(.wide)))",
                action: "Scan", actionLabel: "Scan \(group.title)", perform: { [weak self] in
                    self?.select(.group(group))
                    self?.scan(group)
                }))
        }
        return Array(suggestions.prefix(3))
    }

    /// The overview's scan, from My Activity: the overview comes forward and scans.
    private func scanEverything() {
        select(.overview)
        guard overviewPhase == .home else { return }
        startScan()
    }

    private static func days(from start: Date, to end: Date) -> Int {
        max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0)
    }
}
