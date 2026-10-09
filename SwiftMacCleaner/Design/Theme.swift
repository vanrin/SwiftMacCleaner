//
//  Theme.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The colours of one part of the app: its backdrop, the glow behind its artwork, and its accent.
nonisolated struct Theme: Hashable, Sendable {
    /// The darkest corner of the backdrop.
    let deep: Color
    /// The body of the backdrop.
    let mid: Color
    /// The light behind the artwork, and the fill of the round action button.
    let glow: Color
    /// Rings, icons and anything else that should stand out against the backdrop.
    let accent: Color
    /// The tint of the lens under a glyph. Deep enough for a white glyph to stand out on it in every palette.
    let lens: Color

    /// The accent held back, for what was found but is not ticked.
    var faintAccent: Color { accent.opacity(0.45) }

    /// Builds a palette around one hue, with a neighbouring hue for the glow.
    /// `shadeHue` moves the dark corner towards another hue, the way violet falls off into navy.
    /// `lift` brightens the backdrop for warm hues, which turn to mud when they are as dark as the cool ones.
    init(hue: Double, glowHue: Double, shadeHue: Double? = nil, lift: Double = 0) {
        deep = Color(hue: shadeHue ?? hue, saturation: 0.88, brightness: 0.22 + lift / 2)
        mid = Color(hue: hue, saturation: 0.82, brightness: 0.52 + lift)
        glow = Color(hue: glowHue, saturation: 0.78, brightness: 0.84)
        accent = Color(hue: glowHue, saturation: 0.45, brightness: 1)
        lens = Color(hue: glowHue, saturation: 0.84, brightness: 0.56)
    }

    static let violet = Theme(hue: 0.775, glowHue: 0.85, shadeHue: 0.70)
    static let indigo = Theme(hue: 0.70, glowHue: 0.73, shadeHue: 0.66)
    static let blue = Theme(hue: 0.63, glowHue: 0.59, shadeHue: 0.68)
    static let ocean = Theme(hue: 0.58, glowHue: 0.54, shadeHue: 0.63)
    static let teal = Theme(hue: 0.50, glowHue: 0.46, shadeHue: 0.55)
    static let green = Theme(hue: 0.35, glowHue: 0.28, shadeHue: 0.38)
    static let amber = Theme(hue: 0.10, glowHue: 0.13, shadeHue: 0.06, lift: 0.04)
    static let orange = Theme(hue: 0.045, glowHue: 0.08, shadeHue: 0.02, lift: 0.08)
    static let rose = Theme(hue: 0.97, glowHue: 0.98, shadeHue: 0.93, lift: 0.04)
    static let magenta = Theme(hue: 0.89, glowHue: 0.91, shadeHue: 0.83)
}

extension EnvironmentValues {
    /// The palette of the screen a view is on.
    @Entry var theme: Theme = .violet
}
