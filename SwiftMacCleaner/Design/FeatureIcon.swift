//
//  FeatureIcon.swift
//  SwiftMacCleaner
//

import SwiftUI

/// A glyph on a tinted lens. It stands in for an illustration, so it is decoration:
/// the text beside it carries the meaning.
///
/// The lens is drawn, not system glass: glass gives up its tint whenever the window is not in front,
/// and the tint here says which feature this is.
struct FeatureIcon: View {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ScaledMetric private var diameter: Double
    private let glyph: Image
    private let theme: Theme
    private let isTinted: Bool

    /// - Parameters:
    ///   - glyph: One of the app's own glyphs, or a system symbol for something that is not a feature of the app.
    ///   - isTinted: Off for what has nothing to offer, which leaves the lens clear.
    init(_ glyph: Image, theme: Theme, size: Double = Design.Size.rowIcon, isTinted: Bool = true) {
        self.glyph = glyph
        self.theme = theme
        self.isTinted = isTinted
        _diameter = ScaledMetric(wrappedValue: size, relativeTo: .title3)
    }

    var body: some View {
        glyph
            .symbolRenderingMode(.hierarchical)
            // At the small scale a glyph's grid is drawn exactly as large as the font.
            .imageScale(.small)
            .font(.system(size: diameter * Design.Size.lensGlyphShare))
            .foregroundStyle(.white)
            .frame(width: diameter, height: diameter)
            .background {
                Circle()
                    .fill(fill)
                    .strokeBorder(rim)
                    .shadow(color: theme.deep.opacity(isTinted ? 0.45 : 0), radius: 3, y: 2)
            }
            .accessibilityHidden(true)
    }

    /// With Increase Contrast on, the tint drops to the palette's darkest colour, so both tones of the glyph stand out.
    private var fill: AnyShapeStyle {
        if !isTinted {
            AnyShapeStyle(reduceTransparency ? Design.Surface.solidPanel : Design.Surface.well)
        } else if contrast == .increased {
            AnyShapeStyle(theme.deep)
        } else {
            // Deeper towards the bottom, never lighter than the tint, so the glyph keeps its contrast all the way up.
            AnyShapeStyle(LinearGradient(colors: [theme.lens, theme.lens.mix(with: theme.deep, by: 0.35)],
                                         startPoint: .top, endPoint: .bottom))
        }
    }

    /// The light catching the top of the lens.
    private var rim: AnyShapeStyle {
        if contrast == .increased {
            AnyShapeStyle(Design.Surface.strongBorder)
        } else if isTinted {
            AnyShapeStyle(LinearGradient(colors: [theme.accent, theme.accent.opacity(0.15)],
                                         startPoint: .top, endPoint: .bottom))
        } else {
            AnyShapeStyle(Design.Surface.panelBorder)
        }
    }
}
