//
//  ReviewStepRow.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One group on the confirmation: what it is, what happens to it, and whether it has to wait.
struct ReviewStepRow: View {
    let step: CleanStep
    /// What owns these files is open, so the step is shown but left alone this time.
    let isBlocked: Bool
    /// The operations of the step that wait because an app that keeps their item is open.
    var waitingItems: [CleanOperation] = []
    var showsDivider = true

    var body: some View {
        let waitingSize = waitingItems.reduce(Int64(0)) { $0 + $1.size }
        // With every item waiting, the group is left alone as surely as one that waits as a whole.
        let allWait = !waitingItems.isEmpty && Set(waitingItems.map(\.itemID)) == Set(step.operations.map(\.itemID))
        let isBlocked = isBlocked || allWait
        HStack(spacing: Design.Spacing.medium) {
            VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
                HStack(spacing: Design.Spacing.small) {
                    Text(step.title)
                        .font(.headline)
                        .lineLimit(1)
                    // What rebuilds itself and what is in the Trash are said by the heading the row sits under.
                    if step.aftermath == .downloadsAgain || step.aftermath == .irreplaceable {
                        AftermathBadge(aftermath: step.aftermath)
                    }
                    if isBlocked {
                        Badge(text: step.waitsFor?.badge ?? "Waits for its app", style: .waits)
                    }
                    if step.method == .adminCommand {
                        Badge(text: "Asks for your password", style: .password)
                    }
                }
                Text(detail(isBlocked: isBlocked, allWait: allWait, waitingSize: waitingSize))
                    .font(.callout)
                    .foregroundStyle(.quiet)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: Design.Spacing.medium)
            if step.sizeIsEstimate, step.size > 0 {
                // A task's figure is a guess at what comes back, so it is said as one.
                Text("up to \(ByteFormat.string(step.size))")
                    .font(Design.Typeface.tileBody)
                    .foregroundStyle(.quiet)
                    .monospacedDigit()
            } else {
                SizeLabel(bytes: isBlocked ? step.size : step.size - waitingSize, isEmphasized: !isBlocked)
                    .strikethrough(isBlocked)
            }
        }
        .foregroundStyle(isBlocked ? AnyShapeStyle(.quiet) : AnyShapeStyle(.primary))
        .padding(.horizontal, Design.Spacing.large)
        .padding(.vertical, Design.Spacing.medium)
        .overlay(alignment: .top) {
            Divider()
                .opacity(showsDivider ? 1 : 0)
        }
    }

    private func detail(isBlocked: Bool, allWait: Bool, waitingSize: Int64) -> String {
        if allWait { return "Left alone while the \(waitingItems.count == 1 ? "app that keeps it is" : "apps that keep these are") open" }
        if isBlocked { return "Left alone while \(step.waitsFor?.name ?? "it") is open" }
        guard !waitingItems.isEmpty else { return step.summary }
        let count = Set(waitingItems.map(\.itemID)).count
        return "\(step.summary) · \(count == 1 ? "1 waits" : "\(count) wait") for an open app, \(ByteFormat.string(waitingSize))"
    }
}
