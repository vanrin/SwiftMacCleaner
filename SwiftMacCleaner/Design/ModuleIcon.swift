//
//  ModuleIcon.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The icon of a part of the app, drawn as an object: a face in one smooth gradient, a soft copy of
/// its outline just below, and one white mark. Nothing has a line round it, and the copy is paler
/// than the face, so the icon looks thick without looking heavy. It is decoration: the name beside
/// it carries the meaning.
struct ModuleIcon: View {
    @Environment(\.colorSchemeContrast) private var contrast
    /// One of the `module` symbols: its mark, its body and, in an icon of two objects, the one behind.
    let symbol: ImageResource
    let theme: Theme
    var size = Design.Size.sidebarGlyph
    /// How far the copy sits below the face, in units of the icon's 24-unit grid.
    var depth = Design.Depth.rest
    /// The side of the object that shows, as a direction on screen: straight down shows its lower edge.
    var lean = CGVector(dx: 0, dy: 1)

    /// The gradient of a face runs over the part of the grid a drawing fills: 3 to 21 of its 24 units.
    private static let faceTop = UnitPoint(x: 0.5, y: 0.125)
    private static let faceBottom = UnitPoint(x: 0.5, y: 0.875)

    var body: some View {
        let unit = size / 24
        let shift = CGSize(width: lean.dx * depth * unit / 2, height: lean.dy * depth * unit / 2)
        ZStack {
            // The copy: the body alone, with the mark left out.
            art
                .foregroundStyle(Color.clear, theme.faceCopy, theme.faceCopy)
                .opacity(contrast == .increased ? 0.6 : Design.Depth.copyOpacity)
                .offset(shift)
            art
                .foregroundStyle(AnyShapeStyle(Color.white), face(theme.face), face(theme.backFace))
                .offset(x: -shift.width, y: -shift.height)
        }
        .frame(width: size, height: size)
        .background(alignment: .top) {
            shadow(unit: unit)
        }
        // Drawn once and kept as one picture, with room round it for the copy and the shadow. Left
        // as separate symbols, the icons were drawn again for every frame of anything moving on
        // screen, and a scanning screen took half as much of the processor again.
        .padding(size * 0.25)
        .drawingGroup()
        .padding(-size * 0.25)
        .accessibilityHidden(true)
    }

    private var art: some View {
        Image(symbol)
            .symbolRenderingMode(.palette)
            // At the small scale a glyph's grid is drawn exactly as large as the font.
            .imageScale(.small)
            .font(.system(size: size))
    }

    /// With Increase Contrast on, a face is its lens's darker tone all the way down, so the mark stands out.
    private func face(_ gradient: Gradient) -> AnyShapeStyle {
        if contrast == .increased {
            AnyShapeStyle(theme.lensShade)
        } else {
            AnyShapeStyle(LinearGradient(gradient: gradient, startPoint: Self.faceTop, endPoint: Self.faceBottom))
        }
    }

    /// A faint shadow under the icon. It is there to seat the icon, not to be seen.
    private func shadow(unit: Double) -> some View {
        let strength = depth > 0 ? 0.1 + 0.04 * depth : 0
        let soft = size * 0.07
        return Ellipse()
            .fill(EllipticalGradient(colors: [Design.Ground.shadow.opacity(strength), Design.Ground.shadow.opacity(0)],
                                     startRadiusFraction: 0.15, endRadiusFraction: 0.5))
            .frame(width: size * (0.583 + 0.025 * depth) + soft * 2, height: size * (0.075 + 0.0125 * depth) + soft * 2)
            .offset(x: lean.dx * depth * unit, y: size * (0.846 + 0.0146 * depth) - soft)
    }
}
