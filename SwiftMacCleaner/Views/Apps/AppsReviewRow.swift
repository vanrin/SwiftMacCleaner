//
//  AppsReviewRow.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One app on the confirmation: what happens to it, and when it is open, the button that quits it.
struct AppsReviewRow: View {
    @Environment(AppModel.self) private var model
    let app: InstalledApp
    let step: CleanStep
    var showsDivider = true

    var body: some View {
        let isOpen = model.apps.isRunning(app)
        HStack(spacing: Design.Spacing.medium) {
            AppIconView(url: app.url)
                .saturation(isOpen ? 0.3 : 1)
            VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
                HStack(spacing: Design.Spacing.small) {
                    Text(step.title)
                        .font(.headline)
                        .lineLimit(1)
                    if isOpen {
                        Badge(text: "Open", style: .waits)
                    }
                    if app.needsPassword, step.requiresFirst {
                        Badge(text: "Asks for your password", style: .password)
                    }
                }
                Text(isOpen ? "Left alone while it is open" : step.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Design.Spacing.medium)
            if isOpen {
                Button("Quit", action: quit)
                    .buttonStyle(.pill)
                    .accessibilityLabel("Quit \(app.name)")
                    .help("Asks \(app.name) to quit, as its own Quit command would")
            }
            SizeLabel(bytes: step.size, isEmphasized: !isOpen)
                .strikethrough(isOpen)
        }
        .foregroundStyle(isOpen ? .secondary : .primary)
        .padding(.horizontal, Design.Spacing.large)
        .padding(.vertical, Design.Spacing.medium)
        .overlay(alignment: .top) {
            Divider()
                .opacity(showsDivider ? 1 : 0)
        }
    }

    private func quit() {
        model.apps.quit(app)
    }
}
