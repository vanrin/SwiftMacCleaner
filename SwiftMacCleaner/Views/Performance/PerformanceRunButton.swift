//
//  PerformanceRunButton.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The round button under the manager, with how much is ticked. It opens the confirmation; nothing
/// runs until that is accepted.
struct PerformanceRunButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let performance = model.performance
        let count = performance.selectedCount
        let noun = performance.section == .maintenance ? (count == 1 ? "task" : "tasks") : (count == 1 ? "item" : "items")
        Button(action: showReview) {
            VStack(spacing: 0) {
                Text(performance.section.verb)
                Text("\(count) \(noun)")
                    .font(Design.Typeface.orbButtonDetail)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .buttonStyle(.orb)
        .disabled(count == 0)
        .accessibilityLabel("Review and \(performance.section.verb.lowercased()) \(count) \(noun)")
        .help(count == 0 ? "Tick what you want first" : "Review what will happen, then confirm")
    }

    private func showReview() {
        model.performance.refreshBlocked()
        model.performance.showingReview = true
    }
}
