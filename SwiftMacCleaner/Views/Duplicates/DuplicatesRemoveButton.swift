//
//  DuplicatesRemoveButton.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The round button under the list, with what the ticked files give back. It opens the confirmation;
/// nothing is moved until that is accepted.
struct DuplicatesRemoveButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let duplicates = model.duplicates
        let count = duplicates.selectedCount
        let size = duplicates.selectedSize
        Button(action: showReview) {
            VStack(spacing: 0) {
                Text("Remove")
                // Files that share their space give nothing back, so the count says more than "0 KB" would.
                Text(size > 0 || count == 0 ? ByteFormat.string(size) : "\(count) \(count == 1 ? "file" : "files")")
                    .font(Design.Typeface.orbButtonDetail)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .buttonStyle(.orb)
        .disabled(count == 0)
        .accessibilityLabel("Review and remove \(count == 1 ? "1 duplicate" : "\(count) duplicates"), \(ByteFormat.string(size))")
        .help(count == 0 ? "Tick the copies you want to remove first" : "Review what will happen, then confirm")
    }

    private func showReview() {
        model.duplicates.showingReview = true
    }
}
