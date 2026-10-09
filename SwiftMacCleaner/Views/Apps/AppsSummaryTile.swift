//
//  AppsSummaryTile.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One thing the Applications scan found, as a tile: what it is, the apps it concerns, and a way in.
struct AppsSummaryTile: View {
    @Environment(\.theme) private var theme
    let title: String
    let detail: String
    let glyph: ImageResource
    /// The apps to picture in the corner. Without any, the tile shows its glyph instead.
    var icons: [URL] = []
    /// Whether there is anything behind the tile to review.
    var isActionable = true
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
                HStack {
                    Spacer(minLength: 0)
                    Button("Review", action: action)
                        .buttonStyle(.pill)
                        .disabled(!isActionable)
                        .accessibilityLabel("Review \(title)")
                }
            }
            .padding(Design.Spacing.large)
            .frame(height: Design.Size.tileHeight, alignment: .topLeading)
        }
    }
}
