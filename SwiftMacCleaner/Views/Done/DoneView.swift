//
//  DoneView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The result of a clean-up or of the overview's run: what the disk gained, a receipt, and what is still left to decide.
struct DoneView: View {
    let outcome: CleanOutcome
    /// What the scans still have on offer, which was not ticked or could not be removed this time.
    let remaining: Int64
    /// Leaves this screen for the results, or the opening screen when nothing is left.
    let showResults: () -> Void
    /// What to say under a step that is not a removal, such as a maintenance task. Nil keeps the usual wording.
    var doneDetail: (StepOutcome) -> String? = { _ in nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Design.Spacing.section) {
                DoneHero(outcome: outcome, remaining: remaining, done: showResults)
                DoneFollowUps(outcome: outcome, remaining: remaining, review: showResults)
                ReceiptPanel(outcome: outcome, doneDetail: doneDetail)
            }
            .pageLayout()
        }
    }
}
