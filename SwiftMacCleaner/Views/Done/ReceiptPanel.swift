//
//  ReceiptPanel.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What the clean did, step by step, with a way to the full log.
struct ReceiptPanel: View {
    let outcome: CleanOutcome
    /// What to say under a step that was not skipped, for screens whose steps are not removals. Nil keeps the usual wording.
    var doneDetail: (StepOutcome) -> String? = { _ in nil }

    var body: some View {
        GlassPanel {
            HStack(spacing: Design.Spacing.medium) {
                Text("What happened, step by step")
                    .font(Design.Typeface.tileTitle)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Design.Spacing.medium)
                if outcome.logURL != nil {
                    Button("Open Log", action: openLog)
                        .buttonStyle(.pill)
                }
            }
            .padding(Design.Spacing.large)

            ForEach(outcome.steps) { step in
                VStack(spacing: 0) {
                    Divider()
                    ReceiptRow(step: step, doneDetail: doneDetail(step))
                }
            }
        }
    }

    private func openLog() {
        if let log = outcome.logURL {
            NSWorkspace.shared.open(log)
        }
    }
}
