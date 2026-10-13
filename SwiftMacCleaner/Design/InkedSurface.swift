//
//  InkedSurface.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What everything drawn on the light ground has in common: dark ink for text and graphite for controls.
/// Each window, sheet and popover of the app applies it once.
struct InkedSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            // One level only: a divider takes the third level of a style at full strength, which would
            // rule the rows of a list in heavy lines.
            .foregroundStyle(Design.Ink.primary)
            .tint(Design.Ink.primary)
            // The ground is light whatever the system setting, so what is drawn on it is too.
            .environment(\.colorScheme, .light)
    }
}

extension View {
    func inkedSurface() -> some View {
        modifier(InkedSurface())
    }
}
