//
//  ReceiptRow.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One step of the receipt: whether it ran, what it did, and how much it covered.
struct ReceiptRow: View {
    let step: StepOutcome
    /// What to say under a step that was not skipped, when the usual sentence for its method does not fit.
    var doneDetail: String? = nil

    var body: some View {
        let skipped = step.skippedReason != nil
        HStack(alignment: .top, spacing: Design.Spacing.medium) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(symbolStyle)
                .accessibilityLabel(symbolMeaning)
            TitledDetail(title: step.title, detail: detail, detailLineLimit: nil)
            Spacer(minLength: Design.Spacing.medium)
            // A step that frees nothing, such as a task that was run, has no size worth a column.
            if step.size > 0 {
                SizeLabel(bytes: step.size, isEmphasized: !skipped)
                    .foregroundStyle(skipped ? AnyShapeStyle(.quiet) : AnyShapeStyle(.primary))
            }
        }
        .padding(.horizontal, Design.Spacing.large)
        .padding(.vertical, Design.Spacing.medium)
    }

    private var isClean: Bool { step.failures.isEmpty && step.skippedItems.isEmpty }

    private var symbol: String {
        if step.skippedReason != nil {
            "minus.circle"
        } else if isClean {
            "checkmark.circle.fill"
        } else {
            "exclamationmark.triangle.fill"
        }
    }

    private var symbolStyle: AnyShapeStyle {
        if step.skippedReason != nil {
            AnyShapeStyle(.quiet)
        } else if isClean {
            AnyShapeStyle(.tint)
        } else {
            AnyShapeStyle(Design.Signal.warning)
        }
    }

    private var symbolMeaning: String {
        if step.skippedReason != nil {
            "Skipped"
        } else if isClean {
            "Done"
        } else {
            "Done with problems"
        }
    }

    private var detail: String {
        if let reason = step.skippedReason { return reason }
        let total = step.cleanedItemIDs.count + step.skippedItems.count + step.failures.count
        if !step.skippedItems.isEmpty {
            let done = step.cleanedItemIDs.count
            return "\(verb) \(done) of \(total) \(total == 1 ? "item" : "items"). \(step.skippedItems.count) skipped: \(skippedWhy)."
        }
        if let doneDetail { return doneDetail }
        if let first = step.failures.first {
            let more = step.failures.count > 1 ? " (and \(step.failures.count - 1) more in the log)" : ""
            return first + more
        }
        if step.fate == .trashEmptied { return "Emptied. What was in the Trash cannot be put back." }
        return switch step.method {
        case .delete: "Deleted. It is rebuilt or downloaded again when needed."
        case .trash: "Moved to the Trash. Put Back returns it until the Trash is emptied."
        case .command: "Removed by the tool that owns it."
        case .adminCommand: "Removed with your password. The space comes back over the next minutes."
        case .adminDelete: "Deleted with your password. Newer logs, and the folders themselves, stayed."
        }
    }

    /// Why items were left alone: they changed after the scan, a running program had them open, or some of each.
    private var skippedWhy: String {
        let reasons = step.skippedItems.values
        let appOpen = reasons.count { $0.contains(Cleaner.openAppReason) }
        if appOpen == reasons.count { return appOpen == 1 ? "the app that keeps it was open" : "the apps that keep them were open" }
        let inUse = reasons.count { $0.contains(Cleaner.inUseReason) }
        if appOpen == 0, inUse == 0 { return "changed since the scan" }
        if appOpen == 0 { return inUse == reasons.count ? "open in a running program" : "changed since the scan, or open in a running program" }
        return "their app was open, or they changed since the scan"
    }

    private var verb: String {
        switch step.method {
        case .delete, .adminDelete: "Deleted"
        case .trash: "Moved"
        case .command, .adminCommand: "Removed"
        }
    }
}
