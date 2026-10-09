//
//  SummaryTile.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One thing a scan found, as a tile: what it is, the apps it concerns, and a way in. A tile whose
/// finding can be acted on straight away carries a second, solid button for that.
struct SummaryTile: View {
    @Environment(\.theme) private var theme
    let title: String
    let detail: String
    let glyph: ImageResource
    /// The apps to picture in the corner. Without any, the tile shows its glyph instead.
    var icons: [URL] = []
    /// Whether there is anything behind the tile to review.
    var isActionable = true
    /// System symbols pictured on lenses in the body of the tile, for things that have no icon of their own.
    var symbols: [String] = []
    /// The safety tiers of what the tile holds, as badges at the bottom left.
    var tiers: [SafetyTier] = []
    /// A solid button beside Review, for acting on the finding without looking at it first.
    var primaryTitle: String? = nil
    var primaryAction: () -> Void = {}
    var height = Design.Size.tileHeight
    let action: () -> Void

    var body: some View {
        GlassPanel(cornerRadius: Design.Radius.tile) {
            VStack(alignment: .leading, spacing: Design.Spacing.small) {
                HStack(alignment: .top, spacing: Design.Spacing.medium) {
                    Text(title)
                        .font(Design.Typeface.tileTitle)
                        .lineLimit(2, reservesSpace: true)
                    Spacer(minLength: 0)
                    if icons.isEmpty {
                        FeatureIcon(Image(glyph), theme: theme, size: Design.Size.tileIcon)
                    } else {
                        HStack(spacing: Design.Spacing.tight) {
                            ForEach(icons, id: \.self) { icon in
                                AppIconView(url: icon, size: Design.Size.tileIcon)
                            }
                        }
                    }
                }
                Text(detail)
                    .font(Design.Typeface.tileBody)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Spacer(minLength: 0)
                if !symbols.isEmpty {
                    HStack(spacing: Design.Spacing.large) {
                        Spacer(minLength: 0)
                        ForEach(symbols, id: \.self) { symbol in
                            FeatureIcon(Image(systemName: symbol), theme: theme, size: Design.Size.tileIcon * 1.5)
                        }
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: Design.Spacing.small) {
                    if tiers.isEmpty {
                        Spacer(minLength: 0)
                    } else {
                        // Three badges do not fit beside the buttons on a narrow tile, so they wrap.
                        FlowLayout(spacing: Design.Spacing.small) {
                            ForEach(tiers, id: \.self) { tier in
                                TierBadge(tier: tier)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button("Review", action: action)
                        .buttonStyle(.pill)
                        .disabled(!isActionable)
                        .accessibilityLabel("Review \(title)")
                    if let primaryTitle {
                        Button(primaryTitle, action: primaryAction)
                            .buttonStyle(.primaryPill)
                            .disabled(!isActionable)
                    }
                }
            }
            .padding(Design.Spacing.large)
            .frame(height: height, alignment: .topLeading)
        }
    }
}
