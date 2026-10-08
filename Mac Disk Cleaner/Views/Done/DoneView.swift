//
//  DoneView.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// The result: what the disk gained, a receipt, and what is still left to decide.
struct DoneView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            if let outcome = model.outcome {
                VStack(alignment: .leading, spacing: Design.Spacing.section) {
                    DoneHero(outcome: outcome)
                    DoneFollowUps(outcome: outcome)
                    ReceiptPanel(outcome: outcome)
                }
                .pageLayout()
            }
        }
    }
}
