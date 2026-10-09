//
//  SidebarHintLabel.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The name of a rail entry and what its scan found, as it appears beside the entry.
struct SidebarHintLabel: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let title: String
    var detail: String?

    var body: some View {
        HStack(spacing: Design.Spacing.small) {
            Text(title)
                .fontWeight(.medium)
            if let detail {
                Text(detail)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .padding(.horizontal, Design.Spacing.medium)
        .padding(.vertical, Design.Spacing.small)
        // Drawn rather than glass: it sits over tiles and text, and has to stay readable on all of them.
        .background {
            RoundedRectangle(cornerRadius: Design.Radius.control)
                .fill(theme.deep.opacity(reduceTransparency ? 1 : 0.9))
                .strokeBorder(Design.Surface.panelBorder)
                .shadow(color: theme.deep.opacity(0.35), radius: 9, y: 6)
        }
    }
}
