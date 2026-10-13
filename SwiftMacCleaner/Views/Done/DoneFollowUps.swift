//
//  DoneFollowUps.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What is still open after a clean: things to put back, space that returns later, and what was not ticked.
struct DoneFollowUps: View {
    @Environment(AppModel.self) private var model
    let outcome: CleanOutcome
    /// What is still on offer and was not removed this time.
    let remaining: Int64
    /// Opens the results again, for what is left.
    let review: () -> Void

    var body: some View {
        let estimate = outcome.steps.filter { $0.succeeded && $0.method != .trash }.reduce(Int64(0)) { $0 + $1.size }
        let snapshotsDone = outcome.steps.contains { $0.method == .adminCommand && $0.skippedReason == nil && $0.failures.isEmpty }
        VStack(alignment: .leading, spacing: Design.Spacing.large) {
            if let pending = model.putBackPending {
                PutBackCard(manifest: pending)
            }
            if let message = model.putBackMessage {
                PutBackMessage(text: message)
            }
            if snapshotsDone {
                Notice(
                    symbol: "clock.arrow.circlepath",
                    title: "Snapshots are gone, but macOS returns their space gradually",
                    text: "The space held by local snapshots comes back over the next minutes as APFS reclaims it. The number above will catch up on the next rescan."
                )
            }
            if outcome.reclaimed < estimate / 2, estimate > 500_000_000 {
                Notice(
                    symbol: "hourglass",
                    title: "Less came back than was removed",
                    text: "Files shared with a local snapshot or another copy only free their space once the last reference is gone. macOS usually catches up within a day."
                )
            }
            if remaining > 0 {
                Notice(
                    symbol: "hand.raised.fill",
                    title: "\(ByteFormat.string(remaining)) more found, not removed",
                    text: remainingText
                ) {
                    Button("Review Them", action: review)
                        .buttonStyle(.primaryPill)
                }
            }
        }
    }

    private var remainingText: String {
        var text = "These were not selected, or could not be removed this time."
        if outcome.skippedSize > 0 {
            text += " Quit what was open to include the \(ByteFormat.string(outcome.skippedSize)) that waited."
        }
        return text
    }
}
