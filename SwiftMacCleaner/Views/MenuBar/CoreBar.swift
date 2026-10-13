//
//  CoreBar.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One core in the CPU details: a bar that fills from the bottom as the core gets busier.
struct CoreBar: View {
    @Environment(\.theme) private var theme
    /// From 0 to 1.
    let load: Double
    let width: Double

    var body: some View {
        RoundedRectangle(cornerRadius: Design.Radius.bar)
            .fill(Design.Surface.track)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(theme.accent)
                    // An idle core still shows a sliver, so the bar reads as a bar.
                    .frame(height: max(Design.Spacing.tight / 2, Design.Size.coreBarHeight * min(1, max(0, load))))
            }
            .clipShape(.rect(cornerRadius: Design.Radius.bar))
            .frame(width: width, height: Design.Size.coreBarHeight)
    }
}
