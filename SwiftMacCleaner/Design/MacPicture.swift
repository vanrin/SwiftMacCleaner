//
//  MacPicture.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The picture the app's icon is made of, drawn at whatever size it is given: a MacBook Pro with a swept
/// trail across its display, and the swift that left it crossing the top corner. It is decoration; what
/// a screen has to say is laid over the display by `HeroMac`.
struct MacPicture: View {
    /// The picture is drawn on a grid this size, taken from the icon's artwork.
    static let grid = CGSize(width: 800, height: 518)
    static let aspectRatio = grid.width / grid.height
    private static let lid = CGRect(x: 60, y: 44, width: 680, height: 446)
    private static let bezel = CGRect(x: 66, y: 50, width: 668, height: 434)
    private static let display = CGRect(x: 76, y: 60, width: 648, height: 414)
    private static let base = CGRect(x: 0, y: 486, width: 800, height: 32)
    private static let thumbScoop = CGRect(x: 330, y: 486, width: 140, height: 15)
    private static let camera = CGRect(x: 393, y: 70, width: 14, height: 14)
    /// Where the swift turns about, and how large it is against its own grid.
    private static let swiftPivot = CGPoint(x: 680, y: 96)
    private static let swiftScale = 0.92

    /// Where the display falls when the picture fills `bounds`.
    static func screen(in bounds: CGRect) -> CGRect {
        let unit = bounds.width / grid.width
        return CGRect(x: bounds.minX + display.minX * unit, y: bounds.minY + display.minY * unit,
                      width: display.width * unit, height: display.height * unit)
    }

    var body: some View {
        Canvas { context, size in
            let unit = size.width / Self.grid.width
            context.scaleBy(x: unit, y: unit)
            drawMac(in: &context)
            drawSwift(in: context)
        }
        .accessibilityHidden(true)
    }

    private func drawMac(in context: inout GraphicsContext) {
        let lid = Path(roundedRect: Self.lid, cornerRadii: RectangleCornerRadii(topLeading: 30, bottomLeading: 10, bottomTrailing: 10, topTrailing: 30))
        context.fill(lid, with: .linearGradient(Gradient(colors: [.white, Design.Brand.aluminium]),
                                                startPoint: CGPoint(x: 0, y: Self.lid.minY), endPoint: CGPoint(x: 0, y: Self.lid.maxY)))
        context.stroke(lid, with: .color(Design.Brand.edge), lineWidth: 2)
        let bezel = Path(roundedRect: Self.bezel, cornerRadii: RectangleCornerRadii(topLeading: 24, bottomLeading: 6, bottomTrailing: 6, topTrailing: 24))
        context.fill(bezel, with: .color(Design.Brand.bezel))
        let display = Path(roundedRect: Self.display, cornerRadius: 16)
        context.fill(display, with: .linearGradient(Gradient(colors: [Design.Brand.screenLight, Design.Brand.screenDeep]),
                                                    startPoint: Self.display.origin,
                                                    endPoint: CGPoint(x: Self.display.maxX, y: Self.display.maxY)))

        // The trail is faint where the display's figures sit over it and bright where the swift has just been.
        context.drawLayer { layer in
            layer.clip(to: display)
            layer.fill(trail, with: .linearGradient(
                Gradient(stops: [
                    .init(color: Design.Brand.bloom.opacity(0), location: 0),
                    .init(color: Design.Brand.bloom.opacity(0.16), location: 0.35),
                    .init(color: Design.Brand.bloom.opacity(0.26), location: 0.72),
                    .init(color: .white.opacity(0.9), location: 1),
                ]),
                startPoint: CGPoint(x: 103, y: 446), endPoint: CGPoint(x: 688, y: 96)))
        }
        context.fill(sparkle(at: CGPoint(x: 136, y: 126), radius: 32), with: .color(.white.opacity(0.9)))
        context.fill(sparkle(at: CGPoint(x: 196, y: 88), radius: 14), with: .color(.white.opacity(0.7)))
        context.fill(Path(ellipseIn: Self.camera), with: .color(.black.opacity(0.7)))

        let base = Path(roundedRect: Self.base, cornerRadii: RectangleCornerRadii(topLeading: 6, bottomLeading: 24, bottomTrailing: 24, topTrailing: 6))
        context.fill(base, with: .linearGradient(Gradient(colors: [.white, Design.Brand.aluminium, Design.Brand.aluminiumShade]),
                                                 startPoint: CGPoint(x: 0, y: Self.base.minY), endPoint: CGPoint(x: 0, y: Self.base.maxY)))
        context.stroke(base, with: .color(Design.Brand.edge), lineWidth: 2)
        let scoop = Path(roundedRect: Self.thumbScoop, cornerRadii: RectangleCornerRadii(bottomLeading: 12, bottomTrailing: 12))
        context.fill(scoop, with: .color(Design.Brand.aluminiumShade))
    }

    private func drawSwift(in context: GraphicsContext) {
        let pivot = Self.swiftPivot
        let scale = Self.swiftScale
        let frame = CGRect(x: pivot.x - SwiftMark.grid.width / 2 * scale, y: pivot.y - SwiftMark.headLength * scale,
                           width: SwiftMark.grid.width * scale, height: SwiftMark.grid.height * scale)
        // Up and to the right, an eighth of a turn about the point between its shoulders.
        let turn = CGAffineTransform(translationX: pivot.x, y: pivot.y)
            .rotated(by: .pi / 4)
            .translatedBy(x: -pivot.x, y: -pivot.y)
        let swift = SwiftMark().path(in: frame).applying(turn)
        // Lit from the top left: the gradient runs from one wing tip to the other.
        let reach = SwiftMark.grid.width / 2 * scale * cos(.pi / 4)

        var lifted = context
        lifted.addFilter(.shadow(color: .black.opacity(0.4), radius: 10, x: 4, y: 10))
        lifted.fill(swift, with: .linearGradient(Design.Brand.swift,
                                                 startPoint: CGPoint(x: pivot.x - reach, y: pivot.y - reach),
                                                 endPoint: CGPoint(x: pivot.x + reach, y: pivot.y + reach)))
    }

    /// The band the swift has swept, from a point at the bottom left of the display to full width under its wings.
    private var trail: Path {
        var path = Path()
        path.move(to: CGPoint(x: 103, y: 446))
        path.addCurve(to: CGPoint(x: 622, y: 26), control1: CGPoint(x: 308, y: 436), control2: CGPoint(x: 508, y: 186))
        path.addLine(to: CGPoint(x: 750, y: 154))
        path.addCurve(to: CGPoint(x: 103, y: 446), control1: CGPoint(x: 600, y: 306), control2: CGPoint(x: 358, y: 496))
        path.closeSubpath()
        return path
    }

    /// A four-pointed star with hollow sides.
    private func sparkle(at center: CGPoint, radius: Double) -> Path {
        let pinch = radius * 0.14
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - radius))
        path.addQuadCurve(to: CGPoint(x: center.x + radius, y: center.y), control: CGPoint(x: center.x + pinch, y: center.y - pinch))
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y + radius), control: CGPoint(x: center.x + pinch, y: center.y + pinch))
        path.addQuadCurve(to: CGPoint(x: center.x - radius, y: center.y), control: CGPoint(x: center.x - pinch, y: center.y + pinch))
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y - radius), control: CGPoint(x: center.x - pinch, y: center.y - pinch))
        path.closeSubpath()
        return path
    }
}
