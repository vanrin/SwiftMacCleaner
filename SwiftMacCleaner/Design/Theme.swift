//
//  Theme.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The colours of one part of the app. The window looks the same behind every part; what tells the
/// parts apart is the lens under each one's glyph.
nonisolated struct Theme: Hashable, Sendable {
    /// The tint of the lens under a glyph. Every lens is about as light as the next, so a white glyph
    /// stands out on all of them.
    let lens: Color
    /// The lens towards its bottom edge, and all of it when the user asks for more contrast.
    let lensShade: Color
    /// Rings, bars and dots. The same steel in every part; only a finished clean has its own.
    let accent: Color

    /// The accent held back, for what was found but is not ticked.
    var faintAccent: Color { accent.opacity(0.45) }

    /// Mid enough to show on the light ground and on the Mac's dark display alike.
    private static let steel = Color(hue: 0.622, saturation: 0.436, brightness: 0.639)

    init(lens: Color, shade: Color, accent: Color? = nil) {
        self.lens = lens
        lensShade = shade
        self.accent = accent ?? Self.steel
    }

    static let graphite = Theme(lens: Color(hue: 0.619, saturation: 0.275, brightness: 0.400),
                                shade: Color(hue: 0.625, saturation: 0.392, brightness: 0.200))
    static let indigo = Theme(lens: Color(hue: 0.626, saturation: 0.595, brightness: 0.863),
                              shade: Color(hue: 0.627, saturation: 0.660, brightness: 0.600))
    static let blue = Theme(lens: Color(hue: 0.557, saturation: 0.971, brightness: 0.800),
                            shade: Color(hue: 0.558, saturation: 0.993, brightness: 0.525))
    static let ocean = Theme(lens: Color(hue: 0.522, saturation: 0.939, brightness: 0.643),
                             shade: Color(hue: 0.522, saturation: 0.981, brightness: 0.420))
    static let teal = Theme(lens: Color(hue: 0.486, saturation: 0.966, brightness: 0.580),
                            shade: Color(hue: 0.486, saturation: 1, brightness: 0.376))
    static let green = Theme(lens: Color(hue: 0.413, saturation: 0.922, brightness: 0.600),
                             shade: Color(hue: 0.413, saturation: 1, brightness: 0.392))
    static let amber = Theme(lens: Color(hue: 0.120, saturation: 0.982, brightness: 0.643),
                             shade: Color(hue: 0.119, saturation: 0.991, brightness: 0.420))
    static let rose = Theme(lens: Color(hue: 0.960, saturation: 0.599, brightness: 0.792),
                            shade: Color(hue: 0.954, saturation: 0.688, brightness: 0.541))
    static let violet = Theme(lens: Color(hue: 0.731, saturation: 0.500, brightness: 0.808),
                              shade: Color(hue: 0.737, saturation: 0.570, brightness: 0.557))
    /// A finished clean: green, rings and all.
    static let done = Theme(lens: green.lens, shade: green.lensShade, accent: green.lens)
}

extension EnvironmentValues {
    /// The palette of the screen a view is on.
    @Entry var theme: Theme = .graphite
}
