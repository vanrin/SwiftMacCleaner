//
//  AppsDone.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// The result of an uninstall or a removal of leftovers: what went, the offer to put it back, and a receipt.
struct AppsDone: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let apps = model.apps
        ScrollView {
            if let outcome = apps.outcome {
                VStack(alignment: .leading, spacing: Design.Spacing.section) {
                    GlassPanel {
                        HStack(spacing: Design.Spacing.section) {
                            HeroOrb(progress: 1, size: Design.Size.compactOrb) {
                                Image(systemName: apps.removal.items == 0 ? "minus" : "checkmark")
                                    .font(Design.Typeface.orbFigure)
                                    .accessibilityLabel(apps.removal.items == 0 ? "Nothing removed" : "Done")
                            }
                            VStack(alignment: .leading, spacing: Design.Spacing.xLarge) {
                                IntroHeading(title: title(apps.removal), detail: detail(apps.removal, outcome: outcome))
                                Button("Manage More Items", action: apps.manageMore)
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

    private func title(_ removal: AppsModel.Removal) -> String {
        if removal.items == 0 { return "Nothing was removed" }
        if !removal.isUninstall { return "Leftovers removed" }
        if removal.apps == 0 { return "Files removed" }
        return removal.apps == 1 ? "1 app uninstalled" : "\(removal.apps) apps uninstalled"
    }

    private func detail(_ removal: AppsModel.Removal, outcome: CleanOutcome) -> String {
        let waited = outcome.steps.count { $0.skippedReason != nil }
        let failed = outcome.steps.count { !$0.failures.isEmpty }
        var text = removal.items == 0
            ? "Everything ticked had to be left where it is."
            : "\(ByteFormat.string(removal.size)) in \(removal.items == 1 ? "1 item" : "\(removal.items) items") moved to the Trash. The space comes back once the Trash is emptied."
        if waited > 0 { text += " \(waited == 1 ? "1 app was" : "\(waited) apps were") open and left alone." }
        if failed > 0 { text += " \(failed == 1 ? "1 could" : "\(failed) could") not be moved; the receipt says why." }
        return text
    }
}
