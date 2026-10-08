//
//  GlossyIcon.swift
//  SwiftMacCleaner
//

import SwiftUI

/// A symbol on a glossy tile in its theme's colours. It stands in for an illustration, so it is decoration:
/// the text beside it carries the meaning.
struct GlossyIcon: View {
    let symbol: String
    let theme: Theme
    var size = Design.Size.rowIcon

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3)
            .fill(LinearGradient(colors: [theme.accent, theme.glow, theme.mid], startPoint: .top, endPoint: .bottom))
            .strokeBorder(LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0.08)],
                                         startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .resizable()
                    .scaledToFit()
                    .symbolVariant(.fill)
                    .bold()
                    .foregroundStyle(.white)
                    .shadow(color: theme.deep.opacity(0.5), radius: 1, y: 1)
                    .padding(size * 0.24)
            }
            .shadow(color: theme.deep.opacity(0.45), radius: 3, y: 2)
            .accessibilityHidden(true)
    }
}
