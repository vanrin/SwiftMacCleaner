//
//  Hatch.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// Thin diagonal lines, for a part of a bar that is not quite used and not quite free.
struct Hatch: View {
    var color: Color

    var body: some View {
        Canvas { context, size in
            let step = 6.0
            var x = -size.height
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                context.stroke(path, with: .color(color), lineWidth: 1.5)
                x += step
            }
        }
    }
}
