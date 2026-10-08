//
//  ThemeBackdrop.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// The gradient behind a whole window: bright where the artwork sits, falling off into the dark corner.
/// It fades from one palette to the next as the theme changes.
struct ThemeBackdrop: View {
    let theme: Theme

    var body: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.46, 0.46], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                theme.mid, theme.mid.mix(with: theme.glow, by: 0.15), theme.mid.mix(with: theme.deep, by: 0.3),
                theme.mid.mix(with: theme.deep, by: 0.15), theme.mid.mix(with: theme.glow, by: 0.4), theme.deep.mix(with: theme.mid, by: 0.3),
                theme.mid.mix(with: theme.deep, by: 0.4), theme.deep.mix(with: theme.mid, by: 0.35), theme.deep,
            ]
        )
        .ignoresSafeArea()
        .animation(Design.Motion.theme, value: theme)
        .accessibilityHidden(true)
    }
}
