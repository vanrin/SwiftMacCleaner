//
//  ProtectionRow.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One of the Mac's defences: how it stands, what it is for or what its being off means, and a way to
/// where it is changed.
struct ProtectionRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let finding: ProtectionFinding
    var showsDivider = true

    var body: some View {
        let protection = model.protection
        let check = finding.check
        let isAccepted = finding.state == .needsLook && protection.isAccepted(check)
        HStack(spacing: Design.Spacing.medium) {
            Image(systemName: mark.symbol)
                .font(.title2)
                .foregroundStyle(mark.color)
                .accessibilityLabel(mark.label)
            FeatureIcon(Image(systemName: check.symbol), theme: theme, size: Design.Size.appIcon)
            VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
                HStack(alignment: .firstTextBaseline, spacing: Design.Spacing.small) {
                    Text(check.title)
                        .font(Design.Typeface.rowTitle)
                        .lineLimit(1)
                    Text(finding.status)
                        .font(Design.Typeface.tileBody)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(finding.advice ?? check.purpose)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Design.Spacing.medium)
            if finding.state != .inPlace, !isAccepted, finding.settings != nil {
                Button("Open Settings", action: openSettings)
                    .buttonStyle(.pill)
                    .fixedSize()
                    .accessibilityLabel("Open the settings for \(check.title)")
                    .help("Shows where this is changed in System Settings")
            }
            Menu("More actions for \(check.title)", systemImage: "ellipsis") {
                actions(isAccepted: isAccepted)
            }
            .labelStyle(.iconOnly)
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More")
        }
        .padding(.horizontal, Design.Spacing.large)
        .padding(.vertical, Design.Spacing.medium)
        .overlay(alignment: .top) {
            Divider()
                .opacity(showsDivider ? 1 : 0)
        }
        .contextMenu {
            actions(isAccepted: isAccepted)
        }
    }

    @ViewBuilder
    private func actions(isAccepted: Bool) -> some View {
        if finding.settings != nil {
            Button("Open in System Settings", action: openSettings)
        }
        if finding.state == .needsLook {
            if isAccepted {
                Button("Mention It Again", action: mentionAgain)
            } else {
                Button("Leave It This Way", action: accept)
            }
        }
    }

    /// The sign in front of the row: a tick, a warning, or a question mark. The words beside it say the same.
    private var mark: (symbol: String, color: Color, label: String) {
        switch finding.state {
        case .inPlace: ("checkmark.circle.fill", Design.Signal.safe, "In place")
        case .needsLook: ("exclamationmark.triangle.fill", Design.Signal.warning, "Worth a look")
        case .unknown: ("questionmark.circle.fill", .secondary, "Could not be read")
        }
    }

    private func openSettings() {
        model.protection.openSettings(for: finding)
    }

    private func accept() {
        model.protection.accept(finding.check)
    }

    private func mentionAgain() {
        model.protection.mentionAgain(finding.check)
    }
}
