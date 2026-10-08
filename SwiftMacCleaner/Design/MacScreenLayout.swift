//
//  MacScreenLayout.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Puts what a `HeroMac` shows exactly over the display in its picture, whatever size the picture is drawn at.
struct MacScreenLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let screen = MacPicture.screen(in: bounds)
        for subview in subviews {
            subview.place(at: CGPoint(x: screen.midX, y: screen.midY), anchor: .center, proposal: ProposedViewSize(screen.size))
        }
    }
}
