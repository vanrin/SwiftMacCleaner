//
//  QuietAreasPanel.swift
//  SwiftMacCleaner
//

import SwiftUI

/// A group's areas with nothing to tick, each with the reason, so none of them simply goes missing.
struct QuietAreasPanel: View {
    let areas: [Area]

    var body: some View {
        GlassPanel {
            HStack(spacing: Design.Spacing.medium) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                TitledDetail(title: "Nothing to clean", detail: "Areas with nothing to offer this time, and why.")
            }
            .padding(Design.Spacing.large)

            ForEach(areas) { area in
                VStack(spacing: 0) {
                    Divider()
                    QuietAreaRow(area: area)
                }
            }
        }
    }
}
