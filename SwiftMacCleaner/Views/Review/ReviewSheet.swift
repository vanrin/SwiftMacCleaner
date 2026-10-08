//
//  ReviewSheet.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The last look before anything is removed: what happens to each group, and what was checked.
struct ReviewSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        let plan = model.plan
        // Steps that wait for an open app are shown, but not counted in what this clean frees.
        let blocked = model.blockedSteps(in: plan)
        let total = plan.steps.filter { blocked[$0.id] == nil }.reduce(Int64(0)) { $0 + $1.size }
        let atLeast = model.selectionHasUnknownSize ? "at least " : ""
        VStack(alignment: .leading, spacing: Design.Spacing.xLarge) {
            VStack(alignment: .leading, spacing: Design.Spacing.tight) {
                Text("Clean \(atLeast)\(ByteFormat.string(total)) from \(model.disk.name)?")
                    .font(.title)
                    .bold()
                Text(subtitle(for: plan, blockedCount: blocked.count))
                    .foregroundStyle(.secondary)
            }

            GlassPanel {
                HStack(spacing: Design.Spacing.xLarge) {
                    ReviewFigure(caption: "Free now", value: ByteFormat.string(model.disk.free))
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
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

            VStack(alignment: .leading, spacing: Design.Spacing.small) {
                Text("What will happen")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                GlassPanel {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(plan.steps) { step in
                                ReviewStepRow(step: step, isBlocked: blocked[step.id] != nil,
                                              showsDivider: step.id != plan.steps.first?.id)
                            }
                        }
                    }
                    // Tall enough to show a few steps even when the checks below run long.
                    .frame(minHeight: 150, maxHeight: 300)
                    .scrollBounceBehavior(.basedOnSize)
                }
            }

            VStack(alignment: .leading, spacing: Design.Spacing.small) {
                Text("Before you clean")
                    .font(.headline)
                    .foregroundStyle(.secondary)
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
                Button(copied ? "Copied" : "Copy as Shell Script", action: copyScript)
                    .buttonStyle(.pill)
                Spacer()
                Button("Cancel", role: .cancel, action: cancel)
                    .buttonStyle(.pill)
                    .keyboardShortcut(.cancelAction)
                Button("Clean \(atLeast)\(ByteFormat.string(total))", action: model.clean)
                    .buttonStyle(.primaryPill)
                    .disabled(total == 0 && !model.selectionHasUnknownSize)
            }
        }
        .padding(Design.Spacing.xLarge)
        .frame(width: Design.Size.sheetWidth)
        .presentationBackground {
            ThemeBackdrop(theme: theme)
        }
        .preferredColorScheme(.dark)
    }

    private func copyScript() {
        model.copyShellScript()
        copied = true
    }

    private func cancel() {
        dismiss()
    }

    private func subtitle(for plan: CleanPlan, blockedCount: Int) -> String {
        let count = plan.steps.count - blockedCount
        let groups = count == 1 ? "1 group" : "\(count) groups"
        if plan.needsPassword {
            return "\(groups). One step asks for your password; everything else runs as you."
        }
        let allSafe = plan.steps.allSatisfy { $0.tier == .safe }
        return allSafe
            ? "\(groups), all of it rebuildable. Nothing here needs your password."
            : "\(groups). Nothing here needs your password."
    }

    private func checks(for plan: CleanPlan, blocked: [String: String]) -> [(text: String, isWarning: Bool)] {
        var checks: [(text: String, isWarning: Bool)] = []
        if plan.steps.contains(where: { $0.method == .delete }) {
            var text = "Rebuildable items are deleted right away instead of filling the Trash."
            if plan.trashedSize > 0 {
                text += " Everything Review or Careful goes to the Trash and can be put back from the next screen until you empty it."
            }
            checks.append((text, false))
        } else if plan.trashedSize > 0 {
            checks.append(("Everything here goes to the Trash and can be put back from the next screen until you empty it.", false))
        }
        checks.append(("Every path is checked again just before removal. Anything that changed since the scan is skipped and listed on the receipt.", false))
        if plan.needsPassword {
            let others = plan.steps.count - 1
            checks.append(("Local snapshots: macOS asks for your password for this one step. Cancel that prompt and the other \(others == 1 ? "step" : "\(others) steps") still \(others == 1 ? "runs" : "run").", true))
        }
        let blockedSteps = plan.steps.filter { blocked[$0.id] != nil }
        if !blockedSteps.isEmpty {
            let names = Set(blockedSteps.compactMap { $0.waitsFor?.name }).sorted()
            let who = names.isEmpty ? "Something is still open" : names.joined(separator: " and ") + (names.count == 1 ? " is still open" : " are still open")
            let size = ByteFormat.string(blockedSteps.reduce(Int64(0)) { $0 + $1.size })
            checks.append(("\(who), so \(size) waits until next time. Nothing is quit for you.", true))
        }
        if plan.steps.contains(where: { $0.method == .command || $0.method == .adminCommand }) {
            checks.append(("brew cleanup, docker, simctl and tmutil clean up through their own commands, which cannot be undone.", true))
        }
        if plan.steps.contains(where: { $0.tier == .careful }) {
            checks.append(("This includes items that cannot be recreated.", true))
        }
        return checks
    }
}
