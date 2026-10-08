//
//  SwiftMark.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The swift from the app's icon, seen from above and flying up the page: crescent wings, a small head
/// and a forked tail.
struct SwiftMark: Shape {
    /// The outline is drawn on a grid this size. Its origin sits between the shoulders, `headLength`
    /// below the tip of the head and on the line the bird is mirrored about.
    static let grid = CGSize(width: 430, height: 244)
    static let headLength = 94.0

    /// The right side of the bird from the tip of the head round to the notch of the tail, as curves:
    /// two control points and where each ends.
    private static let rightSide: [(c1: CGPoint, c2: CGPoint, end: CGPoint)] = [
        (CGPoint(x: 14, y: -94), CGPoint(x: 22, y: -78), CGPoint(x: 20, y: -56)),
        (CGPoint(x: 100, y: -72), CGPoint(x: 186, y: -10), CGPoint(x: 215, y: 78)),
        (CGPoint(x: 172, y: 8), CGPoint(x: 96, y: -14), CGPoint(x: 24, y: 14)),
        (CGPoint(x: 22, y: 44), CGPoint(x: 16, y: 70), CGPoint(x: 14, y: 84)),
        (CGPoint(x: 16, y: 110), CGPoint(x: 26, y: 134), CGPoint(x: 36, y: 150)),
        (CGPoint(x: 22, y: 138), CGPoint(x: 8, y: 124), CGPoint(x: 0, y: 116)),
    ]

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / Self.grid.width, rect.height / Self.grid.height)
        let origin = CGPoint(x: rect.midX, y: rect.midY + (Self.headLength - Self.grid.height / 2) * scale)
        func place(_ point: CGPoint, mirrored: Bool = false) -> CGPoint {
            CGPoint(x: origin.x + (mirrored ? -point.x : point.x) * scale, y: origin.y + point.y * scale)
        }

        let head = CGPoint(x: 0, y: -Self.headLength)
        var path = Path()
        path.move(to: place(head))
        for curve in Self.rightSide {
            path.addCurve(to: place(curve.end), control1: place(curve.c1), control2: place(curve.c2))
        }
        // The left side is the right side reflected, drawn back from the tail to the head.
        for index in Self.rightSide.indices.reversed() {
            let curve = Self.rightSide[index]
            let end = index == 0 ? head : Self.rightSide[index - 1].end
            path.addCurve(to: place(end, mirrored: true),
                          control1: place(curve.c2, mirrored: true), control2: place(curve.c1, mirrored: true))
        }
        path.closeSubpath()
        return path
    }
}
