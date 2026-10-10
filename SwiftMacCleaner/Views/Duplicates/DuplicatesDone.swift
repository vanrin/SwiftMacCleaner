//
//  DuplicatesDone.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The result of removing duplicates: what went, the offer to put it back, and a receipt.
struct DuplicatesDone: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let duplicates = model.duplicates
        ScrollView {
            if let outcome = duplicates.outcome {
                VStack(alignment: .leading, spacing: Design.Spacing.section) {
                    GlassPanel {
                        HStack(spacing: Design.Spacing.section) {
                            HeroOrb(progress: 1, size: Design.Size.compactOrb) {
                                Image(systemName: duplicates.removal.files == 0 ? "minus" : "checkmark")
                                    .font(Design.Typeface.orbFigure)
                                    .accessibilityLabel(duplicates.removal.files == 0 ? "Nothing removed" : "Done")
                            }
                            VStack(alignment: .leading, spacing: Design.Spacing.xLarge) {
                                IntroHeading(title: title(duplicates.removal), detail: detail(duplicates.removal))
                                Button(duplicates.groups.isEmpty ? "Start Over" : "Back to the List", action: duplicates.showResults)
                                    .buttonStyle(.primaryPill)
                                    .keyboardShortcut(.defaultAction)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(Design.Spacing.section)
                    }
                    if let pending = model.putBackPending {
                        PutBackCard(manifest: pending)
                    }
                    if let message = model.putBackMessage {
                        PutBackMessage(text: message)
                    }
                    ReceiptPanel(outcome: outcome)
                }
                .pageLayout()
            }
        }
    }

    private func title(_ removal: DuplicatesModel.Removal) -> String {
        if removal.files == 0 { return "Nothing was removed" }
        return removal.files == 1 ? "1 duplicate removed" : "\(removal.files.formatted()) duplicates removed"
    }

    private func detail(_ removal: DuplicatesModel.Removal) -> String {
        var text = removal.files == 0
            ? "Everything ticked had to be left where it is."
            : "A copy of each is still where it was. "
                + (removal.size > 0
                    ? "\(ByteFormat.string(removal.size)) comes back once the Trash is emptied."
                    : "They shared their space with the copies that stay, so no space comes back.")
        if removal.leftOut > 0 {
            text += " \(removal.leftOut == 1 ? "1 file was" : "\(removal.leftOut) files were") left alone; the receipt says why."
        }
        return text
    }
}
