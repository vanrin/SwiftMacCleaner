//
//  SidebarHintOverlay.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Draws the label a rail entry asked for over the window, just past the rail and level with the entry.
/// The sidebar cannot draw it itself: its list clips at the rail's edge.
struct SidebarHintOverlay: View {
    let hint: SidebarHint?

    var body: some View {
        GeometryReader { proxy in
            if let hint {
                SidebarHintLabel(title: hint.title, detail: hint.detail)
                    .fixedSize()
                    // A frame of no size, so the point it is placed at is the middle of the label's leading edge.
                    .frame(width: 0, height: 0, alignment: .leading)
                    .position(x: Design.Size.sidebarRail + Design.Spacing.small, y: proxy[hint.bounds].midY)
                    .transition(.opacity)
            }
        }
        .animation(Design.Motion.sidebarHint, value: hint?.title)
        .allowsHitTesting(false)
        // The entry's own button already says all of this.
        .accessibilityHidden(true)
    }
}
