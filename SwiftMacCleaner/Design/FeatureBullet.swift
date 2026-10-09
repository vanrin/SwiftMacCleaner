//
//  FeatureBullet.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One line of the short list on an intro: an icon and a few words on what this part of the app covers.
struct FeatureBullet: View {
    @Environment(\.theme) private var theme
    let glyph: Image
    let text: String
    /// Smaller, for a list long enough to need two columns.
    var isCompact = false

    var body: some View {
        HStack(spacing: isCompact ? Design.Spacing.medium : Design.Spacing.large) {
            FeatureIcon(glyph, theme: theme, size: isCompact ? Design.Size.rowIcon : Design.Size.featureIcon)
            Text(text)
                .font(isCompact ? Design.Typeface.rowTitle : Design.Typeface.feature)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
