//
//  PerformanceDone.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The result of a run: what was done, the offer to put back what went to the Trash, and a receipt.
struct PerformanceDone: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let performance = model.performance
        ScrollView {
            if let outcome = performance.outcome {
                VStack(alignment: .leading, spacing: Design.Spacing.section) {
                    GlassPanel {
                        HStack(spacing: Design.Spacing.section) {
                            HeroOrb(progress: 1, size: Design.Size.compactOrb) {
                                Image(systemName: performance.run.done == 0 ? "minus" : "checkmark")
                                    .font(Design.Typeface.orbFigure)
                                    .accessibilityLabel(performance.run.done == 0 ? "Nothing done" : "Done")
                            }
                            VStack(alignment: .leading, spacing: Design.Spacing.xLarge) {
                                IntroHeading(title: title(performance.run), detail: detail(performance.run, outcome: outcome))
                                Button("Manage More", action: performance.manageMore)
                                    .buttonStyle(.primaryPill)
                                    .keyboardShortcut(.defaultAction)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(Design.Spacing.section)
                    }
                    if let pending = model.putBackPending, performance.run.section == .backgroundItems {
                        PutBackCard(manifest: pending)
                    }
                    if let message = model.putBackMessage {
                        PutBackMessage(text: message)
                    }
                    ReceiptPanel(outcome: outcome, doneDetail: performance.receiptDetail)
                }
                .pageLayout()
            }
        }
    }

    private func title(_ run: PerformanceModel.Run) -> String {
        switch run.section {
        case .maintenance:
            run.done == 0 ? "Nothing ran" : run.done == 1 ? "1 task ran" : "\(run.done) tasks ran"
        case .loginItems:
            run.done == 0 ? "Nothing was removed" : run.done == 1 ? "1 login item removed" : "\(run.done) login items removed"
        case .backgroundItems:
            run.done == 0 ? "Nothing was removed" : run.done == 1 ? "1 background item removed" : "\(run.done) background items removed"
        }
    }

    private func detail(_ run: PerformanceModel.Run, outcome: CleanOutcome) -> String {
        let waited = outcome.steps.count { $0.skippedReason != nil }
        let failed = outcome.steps.count { !$0.failures.isEmpty }
        var text: String
        switch run.section {
        case .maintenance:
            text = run.done == 0 ? "Everything ticked had to be left alone." : "The receipt says what each task did."
            if run.gained > 0 { text += " The disk gained \(ByteFormat.string(run.gained))." }
        case .loginItems:
            text = run.done == 0 ? "Everything ticked had to be left alone." : "\(run.done == 1 ? "That app" : "Those apps") will not open at the next login. \(run.done == 1 ? "It is" : "They are") still installed."
        case .backgroundItems:
            text = run.done == 0 ? "Everything ticked had to be left alone." : "Unloaded, with the plists in the Trash. Anything still running stops at the next login."
        }
        if waited > 0 { text += " \(waited == 1 ? "1 step" : "\(waited) steps") waited for an app that was open." }
        if failed > 0 { text += " \(failed == 1 ? "1 did" : "\(failed) did") not finish; the receipt says why." }
        return text
    }
}
