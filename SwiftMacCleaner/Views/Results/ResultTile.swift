//
//  ResultTile.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What the scan found in one area, as a tile: how much, how much of it is ticked, and a way in.
struct ResultTile: View {
    @Environment(AppModel.self) private var model
    let area: Area
    let size: Int64

    var body: some View {
        let findings = model.findings(in: area)
        let tiers = SafetyTier.allCases.filter { tier in findings.contains { $0.tier == tier } }
        GlassPanel(cornerRadius: Design.Radius.tile) {
            VStack(alignment: .leading, spacing: Design.Spacing.small) {
                HStack(alignment: .top, spacing: Design.Spacing.medium) {
                    Text("\(ByteFormat.string(size)) in \(area.title)")
                        .font(Design.Typeface.tileTitle)
                        .lineLimit(2, reservesSpace: true)
                    Spacer(minLength: 0)
                    GlossyIcon(symbol: area.symbol, theme: area.theme, size: Design.Size.tileIcon)
                }
                Text("\(ByteFormat.string(model.selectedSize(in: area))) selected")
                    .font(Design.Typeface.tileBody)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                Spacer(minLength: 0)
                HStack(spacing: Design.Spacing.small) {
                    ForEach(tiers, id: \.self) { tier in
                        TierBadge(tier: tier)
                    }
                    Spacer(minLength: Design.Spacing.small)
                    Button("Review", action: showArea)
                        .buttonStyle(.pill)
                        .accessibilityLabel("Review \(area.title)")
                }
            }
            .padding(Design.Spacing.large)
            .frame(height: Design.Size.tileHeight, alignment: .topLeading)
        }
    }

    private func showArea() {
        model.select(.area(area))
    }
}
