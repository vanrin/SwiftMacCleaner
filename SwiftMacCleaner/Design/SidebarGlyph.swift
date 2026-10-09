//
//  SidebarGlyph.swift
//  SwiftMacCleaner
//

import SwiftUI

/// A sidebar icon: two tones of white until its entry is chosen, then its body takes the entry's accent.
struct SidebarGlyph: View {
    let glyph: ImageResource
    let theme: Theme
    var isSelected = false
    /// Pulses the glyph while its part of the scan is under way.
    var isBusy = false

    var body: some View {
        Image(glyph)
            .symbolRenderingMode(isSelected ? .palette : .hierarchical)
            .foregroundStyle(.white, isSelected ? theme.accent : .white)
            .symbolEffect(.pulse, isActive: isBusy)
            .imageScale(.small)
            .font(Design.Typeface.sidebarGlyph)
            .frame(width: Design.Size.sidebarGlyph, height: Design.Size.sidebarGlyph)
            .accessibilityHidden(true)
    }
}
