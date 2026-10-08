//
//  OrbActionModifier.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Stands a screen's round button at the bottom centre, alone. Content that scrolls fades out before it
/// reaches the button, so nothing is ever drawn over or under it.
struct OrbActionModifier<Action: View>: ViewModifier {
    let action: Action

    func body(content: Content) -> some View {
        content
            // Room for the fade, so the last row comes to rest above it.
            .contentMargins(.bottom, Design.Size.orbActionFade, for: .scrollContent)
            .mask {
                OrbActionFade()
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                action
                    .frame(maxWidth: .infinity)
                    .frame(height: Design.Size.orbActionZone)
            }
    }
}

extension View {
    /// Adds the round main action under this screen. See `OrbActionModifier`.
    func orbAction(@ContentBuilder _ action: () -> some View) -> some View {
        modifier(OrbActionModifier(action: action()))
    }
}
