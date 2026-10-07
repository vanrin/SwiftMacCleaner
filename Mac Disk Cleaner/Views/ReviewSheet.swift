//
//  ReviewSheet.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// The last look before anything is removed: what happens to each group, and what was checked.
struct ReviewSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        let plan = model.plan
        // Steps that wait for an open app are shown, but not counted in what this clean frees.
        let blocked = model.blockedSteps(in: plan)
        let total = plan.steps.filter { blocked[$0.id] == nil }.reduce(Int64(0)) { $0 + $1.size }
        let atLeast = model.selectionHasUnknownSize ? "at least " : ""
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Clean \(atLeast)\(ByteFormat.string(total)) from \(model.disk.name)?")
                    .font(.title2.bold())
                Text(subtitle(for: plan, blockedCount: blocked.count))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 20) {
                figure("Free now", ByteFormat.string(model.disk.free))
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                figure("Free after", ByteFormat.string(model.disk.free + total - plan.trashedSize), bold: true)
                Spacer()
                if plan.trashedSize > 0 {
                    figure("In the Trash, can be put back", ByteFormat.string(plan.trashedSize), trailing: true)
                }
            }
            .padding(14)
            .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 8) {
                Text("What will happen")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(plan.steps) { step in
                            Divider()
                            stepRow(step, blocked: blocked[step.id] != nil)
                        }
                    }
                }
                .frame(maxHeight: 344)
                .scrollBounceBehavior(.basedOnSize)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Before you clean")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(checks(for: plan, blocked: blocked), id: \.text) { check in
                    Label {
                        Text(check.text)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: check.isWarning ? "exclamationmark.triangle" : "checkmark")
                            .foregroundStyle(check.isWarning ? AnyShapeStyle(.orange) : AnyShapeStyle(.tint))
                    }
                    .font(.callout)
                }
            }

            HStack(spacing: 10) {
                Button(copied ? "Copied" : "Copy as Shell Script") {
                    model.copyShellScript()
                    copied = true
                }
                .controlSize(.large)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)
                Button("Clean \(atLeast)\(ByteFormat.string(total))") { model.clean() }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(total == 0 && !model.selectionHasUnknownSize)
            }
        }
        .padding(24)
        .frame(width: 640)
    }

    private func stepRow(_ step: CleanStep, blocked: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 8) {
                    Text(step.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(blocked ? .secondary : .primary)
                    if step.tier != .safe { TierBadge(tier: step.tier) }
                    if blocked {
                        Badge(text: step.waitsFor?.badge ?? "Waits", style: .waits)
                    }
                    if step.method == .adminCommand {
                        Badge(text: "Asks for your password", style: .password)
                    }
                }
                Text(blocked ? "Left alone while \(step.waitsFor?.name ?? "it") is open" : step.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 12)
            SizeLabel(bytes: step.size, weight: blocked ? .regular : .semibold)
                .strikethrough(blocked)
                .foregroundStyle(blocked ? .secondary : .primary)
        }
        .padding(.vertical, 9)
    }

    private func figure(_ caption: String, _ value: String, bold: Bool = false, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 1) {
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .monospaced).weight(bold ? .bold : .regular))
        }
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
