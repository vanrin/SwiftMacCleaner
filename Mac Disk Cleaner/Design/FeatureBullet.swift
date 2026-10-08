//
//  FeatureBullet.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// One line of the short list on an intro: a glossy icon and a few words on what this part of the app covers.
struct FeatureBullet: View {
    @Environment(\.theme) private var theme
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: Design.Spacing.large) {
            GlossyIcon(symbol: symbol, theme: theme, size: Design.Size.featureIcon)
            Text(text)
                .font(Design.Typeface.feature)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
