//
//  FlowLayout.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Lays chips out left to right, wrapping to a new line when a row is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    /// The gap between lines. Matches `spacing` unless a caller wants tighter lines.
    var lineSpacing: CGFloat?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 600
        return place(in: width, subviews: subviews, assign: false)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        _ = place(in: bounds.width, subviews: subviews, assign: true, origin: bounds.origin)
    }

    private func place(in width: CGFloat, subviews: Subviews, assign: Bool, origin: CGPoint = .zero) -> CGSize {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + (lineSpacing ?? spacing)
                rowHeight = 0
            }
            if assign {
                subview.place(at: CGPoint(x: origin.x + x, y: origin.y + y), proposal: ProposedViewSize(size))
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return CGSize(width: maxX, height: y + rowHeight)
    }
}
