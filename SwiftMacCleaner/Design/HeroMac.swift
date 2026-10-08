//
//  HeroMac.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The Mac that is the artwork of the opening screen: the picture from the app's icon, with the figure
/// that matters on its display. It grows with the room beside the text.
struct HeroMac<Screen: View>: View {
    @Environment(\.theme) private var theme
    @ContentBuilder var screen: Screen

    var body: some View {
        MacPicture()
            .aspectRatio(MacPicture.aspectRatio, contentMode: .fit)
            .overlay {
                MacScreenLayout {
                    screen
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Design.Spacing.xLarge)
                        .padding(.vertical, Design.Spacing.medium)
                }
            }
            .frame(minWidth: Design.Size.heroMacMinimum, maxWidth: Design.Size.heroMac)
            .background {
                // The glow reaches past the picture without taking up room in the layout.
                Ellipse()
                    .fill(EllipticalGradient(colors: [theme.glow.opacity(0.5), theme.glow.opacity(0)],
                                             center: .center, startRadiusFraction: 0.18, endRadiusFraction: 0.5))
                    .scaleEffect(x: 1.5, y: 2)
            }
            .background(alignment: .bottom) {
                Ellipse()
                    .fill(theme.deep.opacity(0.6))
                    .frame(height: Design.Spacing.xLarge)
                    .blur(radius: Design.Spacing.large)
                    .offset(y: Design.Spacing.large)
            }
            .accessibilityElement(children: .combine)
    }
}
