//
//  ReviewStepRow.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// One group on the confirmation: what it is, what happens to it, and whether it has to wait.
struct ReviewStepRow: View {
    let step: CleanStep
    /// What owns these files is open, so the step is shown but left alone this time.
    let isBlocked: Bool
    var showsDivider = true

    var body: some View {
        HStack(spacing: Design.Spacing.medium) {
            VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
                HStack(spacing: Design.Spacing.small) {
                    Text(step.title)
                        .font(.headline)
                        .lineLimit(1)
                    if step.tier != .safe {
                        TierBadge(tier: step.tier)
                    }
                    if isBlocked {
                        Badge(text: step.waitsFor?.badge ?? "Waits", style: .waits)
                    }
                    if step.method == .adminCommand {
                        Badge(text: "Asks for your password", style: .password)
                    }
                }
                Text(isBlocked ? "Left alone while \(step.waitsFor?.name ?? "it") is open" : step.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: Design.Spacing.medium)
            SizeLabel(bytes: step.size, isEmphasized: !isBlocked)
                .strikethrough(isBlocked)
        }
        .foregroundStyle(isBlocked ? .secondary : .primary)
        .padding(.horizontal, Design.Spacing.large)
        .padding(.vertical, Design.Spacing.medium)
        .overlay(alignment: .top) {
            Divider()
                .opacity(showsDivider ? 1 : 0)
        }
    }
}
