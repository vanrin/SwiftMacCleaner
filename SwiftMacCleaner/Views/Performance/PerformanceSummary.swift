//
//  PerformanceSummary.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What the Performance scan found: how many tasks are worth running, and a tile for each of its three parts.
struct PerformanceSummary: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let performance = model.performance
        let recommended = performance.recommended
        ScrollView {
            VStack(spacing: Design.Spacing.section) {
                VStack(spacing: Design.Spacing.large) {
                    Text(recommended.isEmpty ? "Nothing needs running today" : "\(recommended.count) \(recommended.count == 1 ? "task is" : "tasks are") worth running now")
                        .font(Design.Typeface.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text("Run what is recommended, or pick any task yourself. Login items and background items are listed for you to review.")
                        .font(Design.Typeface.tileBody)
                        .foregroundStyle(.quiet)
                        .multilineTextAlignment(.center)
                    Button("View All Tasks", action: viewTasks)
                        .buttonStyle(.primaryPill)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Design.Spacing.medium)

                // The tasks stand tall on the left; the two lists share the right, as the other tiles do.
                HStack(alignment: .top, spacing: Design.Spacing.large) {
                    SummaryTile(
                        title: tasksTitle(recommended), detail: tasksDetail(recommended), glyph: .glyphMaintenance,
                        symbols: recommended.prefix(3).map(\.task.symbol),
                        primaryTitle: recommended.isEmpty ? nil : "Run Tasks", primaryAction: performance.runRecommended,
                        height: Design.Size.tileHeight * 2 + Design.Spacing.large, action: viewTasks
                    )
                    VStack(spacing: Design.Spacing.large) {
                        SummaryTile(
                            title: loginTitle(performance), detail: loginDetail(performance), glyph: .glyphLoginItems,
                            icons: performance.loginItemIcons,
                            isActionable: !performance.loginItems.isEmpty || performance.loginItemsFailure != nil,
                            action: reviewLoginItems
                        )
                        SummaryTile(
                            title: backgroundTitle(performance), detail: backgroundDetail(performance), glyph: .glyphBackgroundItems,
                            isActionable: !performance.backgroundItems.isEmpty || !performance.backgroundIssues.isEmpty,
                            action: reviewBackgroundItems
                        )
                    }
                }
            }
            .pageLayout()
        }
    }

    private func tasksTitle(_ recommended: [MaintenanceCheck]) -> String {
        switch recommended.count {
        case 0: "No tasks recommended"
        case 1: "1 maintenance task recommended"
        default: "\(recommended.count) maintenance tasks recommended"
        }
    }

    private func tasksDetail(_ recommended: [MaintenanceCheck]) -> String {
        guard !recommended.isEmpty else {
            return "Every task was run recently or has nothing to do. All of them are listed for whenever you want one."
        }
        return PerformancePlan.titles(of: recommended.map(\.task)) + ". The rest are listed for whenever you want them."
    }

    private func loginTitle(_ performance: PerformanceModel) -> String {
        if performance.loginItemsFailure != nil { return "Login items could not be read" }
        let count = performance.loginItems.count
        return count == 0 ? "No login items" : "You have \(count) login \(count == 1 ? "item" : "items")"
    }

    private func loginDetail(_ performance: PerformanceModel) -> String {
        if let failure = performance.loginItemsFailure { return failure }
        let names = performance.loginItems.map(\.name)
        return names.isEmpty
            ? "Nothing opens by itself when you log in."
            : "Apps that open by themselves when you log in: \(names.joined(separator: ", "))."
    }

    private func backgroundTitle(_ performance: PerformanceModel) -> String {
        let count = performance.backgroundItems.count
        return count == 0 ? "No background items" : "\(count) background \(count == 1 ? "item" : "items") found"
    }

    private func backgroundDetail(_ performance: PerformanceModel) -> String {
        let items = performance.backgroundItems
        let issues = performance.backgroundIssues.count
        let unread = issues == 0 ? "" : " \(issues == 1 ? "One thing" : "\(issues) things") could not be read."
        guard !items.isEmpty else { return "No launch agents or daemons from other makers are installed." + unread }
        let daemons = items.count { $0.domain.runsAsRoot }
        let running = items.count(where: \.isRunning)
        return "Launch agents and daemons other makers installed: \(daemons) \(daemons == 1 ? "runs" : "run") as root, \(running) \(running == 1 ? "is" : "are") running right now." + unread
    }

    private func viewTasks() {
        model.performance.manage(.maintenance)
    }

    private func reviewLoginItems() {
        model.performance.manage(.loginItems)
    }

    private func reviewBackgroundItems() {
        model.performance.manage(.backgroundItems)
    }
}
