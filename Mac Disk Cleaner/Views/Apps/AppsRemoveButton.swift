//
//  AppsRemoveButton.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// The round button under the manager, with how much is ticked. It opens the confirmation; nothing is
/// moved until that is accepted.
struct AppsRemoveButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let apps = model.apps
        let size = apps.removesLeftovers ? apps.selectedLeftoverSize : apps.selectedAppSize
        let isEmpty = apps.removesLeftovers ? apps.selectedLeftovers.isEmpty : apps.selectedFiles.isEmpty
        Button(action: showReview) {
            VStack(spacing: 0) {
                Text(apps.removesLeftovers ? "Remove" : "Uninstall")
                Text(ByteFormat.string(size))
                    .font(Design.Typeface.orbButtonDetail)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .buttonStyle(.orb)
        .disabled(isEmpty)
        .accessibilityLabel("Review and \(apps.removesLeftovers ? "remove" : "uninstall") \(ByteFormat.string(size))")
        .help(isEmpty ? "Tick what you want to remove first" : "Review what will happen, then confirm")
    }

    private func showReview() {
        model.apps.refreshRunning()
        model.apps.showingReview = true
    }
}
