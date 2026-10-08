//
//  IntroLayout.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The opening screen of a part of the app: artwork centred in the left half, and in the right half a
/// title, what it does, and whatever needs choosing before the round button is pressed.
struct IntroLayout<Art: View, Details: View>: View {
    @ContentBuilder var art: Art
    @ContentBuilder var details: Details

    var body: some View {
        HStack(spacing: 0) {
            art
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: Design.Spacing.section) {
                details
            }
            .frame(minWidth: Design.Size.introTextMinimum, maxWidth: Design.Size.introTextWidth, alignment: .leading)
            .padding(.trailing, Design.Spacing.xLarge)
            // The text takes the width it wants first; the artwork is centred in what is left.
            .layoutPriority(1)
        }
        .padding(.horizontal, Design.Spacing.pageHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
