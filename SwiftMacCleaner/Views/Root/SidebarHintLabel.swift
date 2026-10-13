//
//  SidebarHintLabel.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The name of a rail entry and what its scan found, as it appears beside the entry.
struct SidebarHintLabel: View {
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
                    .foregroundStyle(.quiet)
            }
        }
        .lineLimit(1)
        .padding(.horizontal, Design.Spacing.medium)
        .padding(.vertical, Design.Spacing.small)
        // Drawn rather than glass: it sits over tiles and text, and has to stay readable on all of them.
        .background {
            RoundedRectangle(cornerRadius: Design.Radius.control)
                .fill(Color.white.opacity(reduceTransparency ? 1 : 0.94))
                .strokeBorder(Design.Surface.panelBorder)
                .shadow(color: Design.Ground.shadow.opacity(0.28), radius: 9, y: 6)
        }
    }
}
