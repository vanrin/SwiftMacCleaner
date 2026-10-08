//
//  OrbButtonStyle.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// The round, glowing button a screen's main action lives on. It stands alone at the bottom of the screen.
struct OrbButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// From 0 to 1. Draws a ring around the button showing how far along the work it would stop is.
    var progress: Double?

    func makeBody(configuration: Configuration) -> some View {
        let diameter = Design.Size.orbButton
        configuration.label
            .font(Design.Typeface.orbButton)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .shadow(color: theme.deep.opacity(0.6), radius: 2, y: 1)
            .padding(.horizontal, Design.Spacing.medium)
            .frame(width: diameter, height: diameter)
            .background {
                // The fill stops short of the pale accent, so the white label stays readable in every palette.
                Circle()
                    .fill(RadialGradient(colors: [theme.glow, theme.mid.mix(with: theme.deep, by: 0.25)],
                                         center: UnitPoint(x: 0.35, y: 0.25), startRadius: 0, endRadius: diameter * 0.75))
                    .strokeBorder(Design.Surface.strongBorder, lineWidth: 2.5)
                    .shadow(color: theme.glow.opacity(isEnabled ? 0.8 : 0), radius: 22, y: 6)
            }
            .overlay {
                ProgressRing(fraction: progress ?? 0, lineWidth: 6)
                    .padding(-10)
                    .opacity(progress == nil ? 0 : 1)
            }
            .contentShape(.circle)
            // Reduce Motion swaps the press-in for a dimming.
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .saturation(isEnabled ? 1 : 0.2)
            .opacity(isEnabled ? 1 : 0.5)
            .animation(Design.Motion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == OrbButtonStyle {
    static var orb: OrbButtonStyle { OrbButtonStyle() }

    static func orb(progress: Double) -> OrbButtonStyle { OrbButtonStyle(progress: progress) }
}
