//
//  SizeBar.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// A thin bar comparing one row's size with the largest row on the screen.
struct SizeBar: View {
    @Environment(\.theme) private var theme
    /// From 0 to 1.
    var fraction: Double
    /// Dimmed when nothing in the row is ticked.
    var isActive = true
    var width = Design.Size.sizeBarWidth
    var alignment = Alignment.trailing

    var body: some View {
        Capsule()
            .fill(Design.Surface.track)
            .frame(width: width, height: Design.Size.sizeBarHeight)
            .overlay(alignment: alignment) {
                Capsule()
                    .fill(isActive ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.secondary))
                    .frame(width: max(Design.Size.sizeBarHeight, width * min(1, max(0, fraction))))
            }
            .accessibilityHidden(true)
    }
}
