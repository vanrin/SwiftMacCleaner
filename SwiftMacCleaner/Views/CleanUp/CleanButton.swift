//
//  CleanButton.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The round button under a clean-up's results or the overview's, with how much is ticked. It opens
/// the confirmation; nothing is removed until that is accepted.
struct CleanButton: View {
    var title = "Clean"
    let size: Int64
    /// Something ticked has no size macOS can report, so the figure is "at least".
    var hasUnknownSize = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(title)
                Text(ByteFormat.string(size))
                    .font(Design.Typeface.orbButtonDetail)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .buttonStyle(.orb)
        .disabled(!isEnabled || (size == 0 && !hasUnknownSize))
        .accessibilityLabel(reviewTitle)
        .help("Review what will happen, then confirm")
    }

    private var reviewTitle: String {
        let figure = ByteFormat.string(size)
        return hasUnknownSize ? "Review and \(title.lowercased()) at least \(figure)" : "Review and \(title.lowercased()) \(figure)"
    }
}
