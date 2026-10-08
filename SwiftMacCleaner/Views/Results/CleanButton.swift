//
//  CleanButton.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The round button under the results, with how much is ticked. It opens the confirmation; nothing is
/// removed until that is accepted.
struct CleanButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button(action: showReview) {
            VStack(spacing: 0) {
                Text("Clean")
                Text(ByteFormat.string(model.selectedSize))
                    .font(Design.Typeface.orbButtonDetail)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .buttonStyle(.orb)
        .disabled(model.selectedSize == 0 && !model.selectionHasUnknownSize)
        .accessibilityLabel(reviewTitle)
        .help("Review what will happen, then confirm")
    }

    private var reviewTitle: String {
        let size = ByteFormat.string(model.selectedSize)
        return model.selectionHasUnknownSize ? "Review and Clean at least \(size)" : "Review and Clean \(size)"
    }

    private func showReview() {
        model.showingReview = true
    }
}
