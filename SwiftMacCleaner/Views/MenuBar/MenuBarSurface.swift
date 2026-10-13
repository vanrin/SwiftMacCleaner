//
//  MenuBarSurface.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What the menu bar popover and the details beside it have in common: their width, the ground,
/// and the light look.
struct MenuBarSurface: ViewModifier {
    /// The palette of everything under the menu bar item.
    static let theme = Theme.graphite

    func body(content: Content) -> some View {
        content
            .padding(Design.Spacing.large)
            .frame(width: Design.Size.menuBarWidth)
            .background {
                ThemeBackdrop()
            }
            .environment(\.theme, Self.theme)
            // A menu bar window keeps the system's appearance whatever is preferred, so the light scheme is set
            // on the content itself. Otherwise the text is white on the ground while the Mac is in Dark mode.
            .inkedSurface()
            .typesettingLanguage(Design.language)
    }
}

extension View {
    func menuBarSurface() -> some View {
        modifier(MenuBarSurface())
    }
}
