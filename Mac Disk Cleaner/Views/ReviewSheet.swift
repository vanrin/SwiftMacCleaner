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
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Clean \(ByteFormat.string(total)) from \(model.disk.name)?")
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
                    figure("In the Trash", ByteFormat.string(plan.trashedSize), trailing: true)
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
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 8) {
                                        Text(step.title)
                                            .fontWeight(.semibold)
                                        if step.tier != .safe { TierBadge(tier: step.tier) }
                                    }
                                    Text(blocked[step.id] == nil ? step.summary : "Left alone while Xcode is open")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer(minLength: 12)
                                SizeLabel(bytes: step.size, weight: blocked[step.id] == nil ? .semibold : .regular)
                                    .strikethrough(blocked[step.id] != nil)
                                    .foregroundStyle(blocked[step.id] == nil ? .primary : .secondary)
                            }
                            .padding(.vertical, 9)
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
                ForEach(checks(for: plan), id: \.text) { check in
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
                Button("Clean \(ByteFormat.string(total))") { model.clean() }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(total == 0)
            }
        }
        .padding(24)
        .frame(width: 620)
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
        let allSafe = plan.steps.allSatisfy { $0.tier == .safe }
        return allSafe
            ? "\(groups), all of it rebuildable. Nothing here needs your password."
            : "\(groups). Nothing here needs your password."
    }

    private func checks(for plan: CleanPlan) -> [(text: String, isWarning: Bool)] {
        var checks: [(text: String, isWarning: Bool)] = []
        if plan.steps.contains(where: { $0.method == .delete }) {
            checks.append(("Rebuildable items are deleted right away instead of filling the Trash.", false))
        }
        if plan.steps.contains(where: { $0.method == .command }) {
            checks.append(("Docker and the simulators clean up through their own commands, which cannot be undone.", true))
        }
        if plan.trashedSize > 0 {
            checks.append(("\(ByteFormat.string(plan.trashedSize)) goes to the Trash. That space comes back when you empty it.", false))
        }
        if plan.steps.contains(where: { $0.tier == .careful }) {
            checks.append(("This includes items that cannot be recreated.", true))
        }
        if plan.steps.contains(where: { $0.quitBundleID.map(model.isRunning(bundleID:)) == true }) {
            checks.append(("Xcode is open, so DerivedData is left alone this time. Quit Xcode first to include it.", true))
        }
        return checks
    }
}
