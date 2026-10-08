//
//  SidebarGlyph.swift
//  SwiftMacCleaner
//

import SwiftUI

/// A sidebar icon: pale and glossy until its entry is chosen, then in that entry's own colours.
struct SidebarGlyph: View {
    let symbol: String
    let theme: Theme
    var isSelected = false

    var body: some View {
        Image(systemName: symbol)
            .resizable()
            .scaledToFit()
            .symbolVariant(.fill)
            .foregroundStyle(
                LinearGradient(colors: isSelected ? [.white, theme.accent, theme.glow] : [.white, .white.opacity(0.6)],
                               startPoint: .top, endPoint: .bottom)
            )
            .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
            .padding(3)
            .frame(width: Design.Size.sidebarGlyph, height: Design.Size.sidebarGlyph)
            .accessibilityHidden(true)
    }
}
