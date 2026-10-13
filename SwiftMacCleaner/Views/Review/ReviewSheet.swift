//
//  ReviewSheet.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The last look before anything is removed: what happens to each group, and what was checked. One
/// clean-up's confirmation, or the overview's over every ticked part.
struct ReviewSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// What the button says: "Clean" for a clean-up, "Run" for the overview, whose plan also has tasks in it.
    var verb = "Clean"
    let plan: CleanPlan
    /// Steps that wait for an open app, by id, with the reason. Shown, but not counted in what this clean frees.
    let blocked: [String: String]
    /// Items that wait because an app that keeps them is open, by id, with the reason. Shown with
    /// their group, and not counted in what this clean frees.
    var waiting: [String: String] = [:]
    /// The open apps something here waits for, each with how much, and the way to ask one to quit.
    var blockingApps: [BlockingApp] = []
    var quit: (OpenApp) -> Void = { _ in }
    /// Something ticked has no size macOS can report, so the figure is "at least".
    let hasUnknownSize: Bool
    let clean: () -> Void
    let copyScript: () -> Void
    @State private var copied = false

    var body: some View {
        let total = plan.size(leavingOut: Set(blocked.keys), waiting: Set(waiting.keys))
        let atLeast = hasUnknownSize ? "at least " : ""
        VStack(alignment: .leading, spacing: Design.Spacing.xLarge) {
            VStack(alignment: .leading, spacing: Design.Spacing.tight) {
                Text("\(verb) \(atLeast)\(ByteFormat.string(total)) from \(model.disk.name)?")
                    .font(.title)
                    .bold()
                Text(subtitle(for: plan, blockedCount: blocked.count))
                    .foregroundStyle(.quiet)
            }

            GlassPanel {
                HStack(spacing: Design.Spacing.xLarge) {
                    ReviewFigure(caption: "Free now", value: ByteFormat.string(model.disk.free))
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.quiet)
                        .accessibilityHidden(true)
                    ReviewFigure(caption: "Free after", value: ByteFormat.string(model.disk.free + total - plan.trashedSize),
                                 isEmphasized: true)
                    Spacer()
                    if plan.trashedSize > 0 {
                        ReviewFigure(caption: "In the Trash, can be put back", value: ByteFormat.string(plan.trashedSize),
                                     alignment: .trailing)
                    }
                }
                .padding(Design.Spacing.large)
            }

            // The one thing to decide comes first: what waits for an app, and the way to ask it to quit.
            if !blockingApps.isEmpty {
                VStack(alignment: .leading, spacing: Design.Spacing.small) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
                            Text(blockingApps.count == 1 ? "Open app" : "Open apps")
                                .font(.headline)
                                .foregroundStyle(.quiet)
                            Text("What \(blockingApps.count == 1 ? "it keeps" : "they keep") waits until \(blockingApps.count == 1 ? "it has" : "they have") quit. Nothing is quit unless you ask.")
                                .font(.callout)
                                .foregroundStyle(.quiet)
                        }
                        Spacer()
                        if blockingApps.count > 1 {
                            Button("Quit All", action: quitAll)
                                .buttonStyle(.pill)
                                .help("Asks each of them to quit, as its own Quit command would")
                        }
                    }
                    GlassPanel {
                        ForEach(blockingApps) { entry in
                            ReviewOpenAppRow(entry: entry, showsDivider: entry.id != blockingApps.first?.id) {
                                quit(entry.app)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: Design.Spacing.small) {
                Text("What will happen")
                    .font(.headline)
                    .foregroundStyle(.quiet)
                GlassPanel {
                    ScrollView {
                        // Grouped by what becomes of each group, so what cannot be undone is said once and plainly.
                        VStack(spacing: 0) {
                            let fates = CleanFate.allCases.filter { fate in plan.steps.contains { $0.fate == fate } }
                            ForEach(fates) { fate in
                                let steps = plan.steps.filter { $0.fate == fate }
                                ReviewFateRow(fate: fate,
                                              size: CleanPlan(steps: steps).size(leavingOut: Set(blocked.keys), waiting: Set(waiting.keys)),
                                              showsDivider: fate != fates.first)
                                ForEach(steps) { step in
                                    ReviewStepRow(step: step, isBlocked: blocked[step.id] != nil,
                                                  waitingItems: step.operations.filter { waiting[$0.itemID] != nil },
                                                  showsDivider: step.id != steps.first?.id)
                                }
                            }
                        }
                    }
                    // Tall enough to show a few steps even when the checks below run long, and shorter
                    // when the open apps above take their share of the sheet.
                    .frame(minHeight: 150, maxHeight: blockingApps.isEmpty ? 300 : 190)
                    .scrollBounceBehavior(.basedOnSize)
                }
            }

            VStack(alignment: .leading, spacing: Design.Spacing.small) {
                Text("Before you clean")
                    .font(.headline)
                    .foregroundStyle(.quiet)
                ForEach(checks(for: plan, blocked: blocked), id: \.text) { check in
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
                Button(copied ? "Copied" : "Copy as Shell Script", action: copyShellScript)
                    .buttonStyle(.pill)
                Spacer()
                Button("Cancel", role: .cancel, action: cancel)
                    .buttonStyle(.pill)
                    .keyboardShortcut(.cancelAction)
                Button("\(verb) \(atLeast)\(ByteFormat.string(total))", action: clean)
                    .buttonStyle(.primaryPill)
                    .disabled(total == 0 && !hasUnknownSize && !plan.steps.contains { $0.size == 0 })
            }
        }
        .padding(Design.Spacing.xLarge)
        .frame(width: Design.Size.sheetWidth)
        .presentationBackground {
            ThemeBackdrop()
        }
        .inkedSurface()
        .preferredColorScheme(.light)
    }

    private func copyShellScript() {
        copyScript()
        copied = true
    }

    private func cancel() {
        dismiss()
    }

    private func quitAll() {
        for entry in blockingApps { quit(entry.app) }
    }

    private func subtitle(for plan: CleanPlan, blockedCount: Int) -> String {
        let count = plan.steps.count - blockedCount
        let groups = count == 1 ? "1 group" : "\(count) groups"
        return switch plan.passwordPromptCount {
        case 0: "\(groups). Nothing here needs your password."
        case 1: "\(groups). macOS asks for your password once; everything else runs as you."
        default: "\(groups). macOS asks for your password \(plan.passwordPromptTimes), once for each group that needs root."
        }
    }

    private func checks(for plan: CleanPlan, blocked: [String: String]) -> [(text: String, isWarning: Bool)] {
        var checks: [(text: String, isWarning: Bool)] = []
        let emptiesTrash = plan.steps.contains { $0.fate == .trashEmptied }
        if plan.trashedSize == 0, plan.steps.contains(where: { $0.method.isFinal }) {
            var text = "Nothing in this run goes to the Trash, so Put Back will have nothing to offer."
            if plan.steps.contains(where: { $0.aftermath == .rebuilds }) { text += " What is deleted is made again by whatever made it." }
            if emptiesTrash { text += " What is already in the Trash is gone for good." }
            checks.append((text, true))
        } else if plan.steps.contains(where: { $0.method == .delete || $0.method == .adminDelete }) {
            var text = "What rebuilds itself is deleted right away instead of filling the Trash. Everything else goes to the Trash and can be put back from the next screen until you empty it."
            if emptiesTrash { text += " What is already in the Trash is gone for good." }
            checks.append((text, emptiesTrash))
        } else if plan.trashedSize > 0 {
            checks.append(("Everything here goes to the Trash and can be put back from the next screen until you empty it.", false))
        }
        checks.append(("Every path is checked again just before removal. Anything that changed since the scan is skipped and listed on the receipt.", false))
        if plan.needsPassword {
            let prompts = plan.passwordPromptCount
            var text = prompts == 1
                ? "macOS asks for your password for the one group that needs root."
                : "macOS asks for your password \(plan.passwordPromptTimes), once for each group that needs root."
            if plan.steps.count > prompts {
                text += " Cancel \(prompts == 1 ? "that prompt" : "a prompt") and everything else still runs."
            }
            checks.append((text, true))
        }
        let blockedSteps = plan.steps.filter { blocked[$0.id] != nil }
        let waitingSize = blockedSteps.reduce(Int64(0)) { $0 + $1.size }
            + plan.waitingSize(blocked: Set(blocked.keys), waiting: Set(waiting.keys))
        if waitingSize > 0 || !blockedSteps.isEmpty {
            // Apps are listed at the top with a way to quit each. A background process cannot be
            // asked to quit from here, so what waits for one is said here instead.
            let apps = Set(blockingApps.map(\.app.name))
            let others = Set(blockedSteps.compactMap { $0.waitsFor?.name }).subtracting(apps).sorted()
            if !others.isEmpty {
                let size = blockedSteps.filter { others.contains($0.waitsFor?.name ?? "") }.reduce(Int64(0)) { $0 + $1.size }
                checks.append(("\(ListFormat.string(others)) \(others.count == 1 ? "is" : "are") still running, so \(ByteFormat.string(size)) waits until next time. Nothing is stopped for you.", true))
            } else if apps.isEmpty {
                checks.append(("Something is still open, so \(ByteFormat.string(waitingSize)) waits until next time. Nothing is quit for you.", true))
            }
        }
        if plan.steps.contains(where: { $0.method == .command || $0.method == .adminCommand }) {
            checks.append(("Commands such as brew cleanup, docker, simctl, tmutil and the maintenance tasks run as they are, which cannot be undone.", true))
        }
        if plan.steps.contains(where: { $0.aftermath == .irreplaceable }) {
            checks.append(("This includes items that cannot be recreated.", true))
        }
        return checks
    }
}
