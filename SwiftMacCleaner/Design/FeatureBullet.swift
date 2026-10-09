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

    var body: some View {
        HStack(spacing: Design.Spacing.large) {
            FeatureIcon(glyph, theme: theme, size: Design.Size.featureIcon)
            Text(text)
                .font(Design.Typeface.feature)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
