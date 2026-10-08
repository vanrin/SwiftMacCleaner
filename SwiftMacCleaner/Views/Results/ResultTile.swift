//
//  ResultTile.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What the scan found in one area, or in every developer area together, as a tile: how much, how much
/// of it is ticked, and a way in.
struct ResultTile: View {
    @Environment(AppModel.self) private var model
    /// The page Review opens, which is also what the tile is named after.
    let item: SidebarItem

    var body: some View {
        let findings = model.findings(under: item)
        let tiers = SafetyTier.allCases.filter { tier in findings.contains { $0.tier == tier } }
        GlassPanel(cornerRadius: Design.Radius.tile) {
            VStack(alignment: .leading, spacing: Design.Spacing.small) {
                HStack(alignment: .top, spacing: Design.Spacing.medium) {
                    Text("\(ByteFormat.string(model.foundSize(under: item))) in \(item.title)")
                        .font(Design.Typeface.tileTitle)
                        .lineLimit(2, reservesSpace: true)
                        // A long name on a narrow tile is set a little smaller rather than cut short.
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    GlossyIcon(symbol: item.symbol, theme: item.theme, size: Design.Size.tileIcon)
                }
                Text("\(ByteFormat.string(model.selectedSize(under: item))) selected")
                    .font(Design.Typeface.tileBody)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                Spacer(minLength: 0)
                HStack(spacing: Design.Spacing.small) {
                    // Three badges do not fit beside the button on a narrow tile, so they wrap instead
                    // of squeezing its label.
                    FlowLayout(spacing: Design.Spacing.small) {
                        ForEach(tiers, id: \.self) { tier in
                            TierBadge(tier: tier)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Review", action: showPage)
                        .buttonStyle(.pill)
                        .fixedSize()
                        .accessibilityLabel("Review \(item.title)")
                }
            }
            .padding(Design.Spacing.large)
            .frame(height: Design.Size.tileHeight, alignment: .topLeading)
        }
    }

    private func showPage() {
        model.select(item)
    }
}
