//
//  PerformanceReviewSheet.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The last look before tasks run or items are removed: what happens, what waits, and what macOS will ask.
struct PerformanceReviewSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let performance = model.performance
        let plan = performance.plan
        let blocked = performance.blockedSteps(in: plan)
        let section = performance.section
        let count = section == .maintenance ? performance.selectedCount : plan.steps.count
        let noun = section == .maintenance ? (count == 1 ? "task" : "tasks") : (count == 1 ? "item" : "items")
        VStack(alignment: .leading, spacing: Design.Spacing.xLarge) {
            VStack(alignment: .leading, spacing: Design.Spacing.tight) {
                Text("\(section.verb) \(count) \(noun)?")
                    .font(.title)
                    .bold()
                Text(subtitle(for: section))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            GlassPanel {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(plan.steps) { step in
                            PerformanceReviewRow(step: step, isBlocked: blocked[step.id] != nil, showsDivider: step.id != plan.steps.first?.id)
                        }
                    }
                }
                .frame(minHeight: 120, maxHeight: 300)
                .scrollBounceBehavior(.basedOnSize)
            }

            VStack(alignment: .leading, spacing: Design.Spacing.small) {
                Text("Before you \(section.verb.lowercased())")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                ForEach(checks(performance, plan: plan, blocked: blocked), id: \.text) { check in
                    Label {
                        Text(check.text)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: check.isWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(check.isWarning ? AnyShapeStyle(Design.Signal.warning) : AnyShapeStyle(.tint))
                    }
                    .font(.callout)
                }
            }

            HStack(spacing: Design.Spacing.medium) {
                Spacer()
                Button("Cancel", role: .cancel, action: cancel)
                    .buttonStyle(.pill)
                    .keyboardShortcut(.cancelAction)
                Button("\(section.verb) \(count) \(noun.capitalized)", action: performance.start)
                    .buttonStyle(.primaryPill)
                    .disabled(plan.steps.count == blocked.count)
            }
        }
        .padding(Design.Spacing.xLarge)
        .frame(width: Design.Size.sheetWidth)
        .presentationBackground {
            ThemeBackdrop(theme: theme)
        }
        .preferredColorScheme(.dark)
    }

    private func cancel() {
        dismiss()
    }

    private func subtitle(for section: PerformanceModel.Section) -> String {
        switch section {
        case .maintenance:
            "Each task runs in turn. The next screen has a receipt that says what each one did."
        case .loginItems:
            "The apps stay installed; they only stop opening when you log in. Add one back any time in System Settings › General › Login Items."
        case .backgroundItems:
            "Each one is unloaded and its plist moved to the Trash. The app it belongs to may offer to install it again the next time it opens."
        }
    }

    private func checks(_ performance: PerformanceModel, plan: CleanPlan, blocked: [String: String]) -> [(text: String, isWarning: Bool)] {
        var checks: [(text: String, isWarning: Bool)] = []
        if plan.needsPassword {
            checks.append(("macOS asks for your password once, for what has to run as root.", true))
        }
        if !blocked.isEmpty {
            let names = plan.steps.filter { blocked[$0.id] != nil }.compactMap { $0.waitsFor?.name }
            let name = Set(names).sorted().joined(separator: " and ")
            checks.append(("\(name) is open, so \(blocked.count == 1 ? "that task" : "those tasks") will be left alone this time. Quit \(name) first to include \(blocked.count == 1 ? "it" : "them"). Nothing is quit for you.", true))
        }
        switch performance.section {
        case .maintenance:
            checks.append(("Nothing is deleted. Each task only asks macOS to do what it would do itself, and a log keeps what every tool said.", false))
            if performance.selectedTasks.contains(.purgeableSpace) {
                checks.append(("Freeing purgeable space reserves the disk's free space for up to a minute. Leave the Mac alone while it runs.", true))
            }
            if performance.selectedTasks.contains(.reindexSpotlight) {
                checks.append(("Spotlight rebuilds its index in the background afterwards, which can take hours and uses the CPU meanwhile.", true))
            }
        case .loginItems:
            checks.append(("macOS may ask once to let SwiftMacCleaner control System Events, which is how login items are changed.", false))
        case .backgroundItems:
            if plan.steps.contains(where: { $0.method == .trash }) {
                checks.append(("Put Back on the next screen returns a plist to its folder, and it loads again at the next login.", false))
            }
            checks.append(("A running item keeps running until you log out, or restart for a daemon. It is gone after that.", false))
        }
        return checks
    }
}
