//
//  MenuBarSurface.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What the menu bar popover and the details beside it have in common: their width, the backdrop,
/// and the dark look.
struct MenuBarSurface: ViewModifier {
    /// The palette of everything under the menu bar item.
    static let theme = Theme.violet

    func body(content: Content) -> some View {
        content
            .padding(Design.Spacing.large)
            .frame(width: Design.Size.menuBarWidth)
            .background {
                ThemeBackdrop(theme: Self.theme)
            }
            .environment(\.theme, Self.theme)
            .tint(Self.theme.accent)
            // A menu bar window keeps the system's appearance whatever is preferred, so the dark scheme is set
            // on the content itself. Otherwise the text is black on the backdrop while the Mac is in Light mode.
            .environment(\.colorScheme, .dark)
            .typesettingLanguage(Design.language)
    }
}

extension View {
    func menuBarSurface() -> some View {
        modifier(MenuBarSurface())
    }
}
