//
//  SidebarLabel.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// What a sidebar entry looks like: its icon, its name, and what the scan found there.
struct SidebarLabel: View {
    let title: String
    let symbol: String
    let theme: Theme
    var badge: String?
    var isSelected = false
    var isHovered = false

    var body: some View {
        HStack(spacing: Design.Spacing.medium) {
            SidebarGlyph(symbol: symbol, theme: theme, isSelected: isSelected)
            Text(title)
                .font(Design.Typeface.sidebar)
                .lineLimit(1)
            Spacer(minLength: Design.Spacing.tight)
            if let badge {
                Text(badge)
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
        }
        .padding(.horizontal, Design.Spacing.small + Design.Spacing.tight / 2)
        .frame(height: Design.Size.sidebarRow)
        .background {
            RoundedRectangle(cornerRadius: Design.Radius.control)
                .fill(isSelected ? Design.Surface.quietButton : isHovered ? Design.Surface.hover : .clear)
                .strokeBorder(isSelected ? Design.Surface.panelBorder : .clear)
        }
        .contentShape(.rect(cornerRadius: Design.Radius.control))
    }
}
