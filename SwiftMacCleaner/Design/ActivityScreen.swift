//
//  ActivityScreen.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What a screen shows while work is under way: the artwork in the middle, what is happening in large type
/// under it, and one quieter line with the detail.
struct ActivityScreen<Art: View>: View {
    let title: String
    let detail: String
    /// Set in a fixed-width face, for a path.
    var detailIsPath = false
    @ContentBuilder var art: Art

    var body: some View {
        VStack(spacing: Design.Spacing.section) {
            art
            VStack(spacing: Design.Spacing.medium) {
                Text(title)
                    .font(Design.Typeface.heroTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(detail)
                    .font(detailIsPath ? Design.Typeface.code : Design.Typeface.heroSubtitle)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, Design.Spacing.pageHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
