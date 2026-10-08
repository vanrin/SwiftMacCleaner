//
//  ProportionalRow.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// Lays views out left to right, each as wide as its share of a total. What is left over stays empty.
struct ProportionalRow: Layout {
    var total: Double
    var spacing = Design.Spacing.hairline

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for subview in subviews {
            let share = total > 0 ? subview[ProportionKey.self] / total : 0
            let width = max(0, bounds.width * share)
            subview.place(at: CGPoint(x: x, y: bounds.minY),
                          proposal: ProposedViewSize(width: max(0, width - spacing), height: bounds.height))
            x += width
        }
    }
}
