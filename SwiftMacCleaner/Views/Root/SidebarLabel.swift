//
//  SidebarLabel.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What a sidebar entry looks like: its icon, its name, and what the scan found there. On the rail
/// only the icon shows, with a dot on it when the scan found something.
struct SidebarLabel: View {
    /// The palette of the screen in view, for the dot. The entry's own palette colours its icon.
    @Environment(\.theme) private var screen
    /// The entry is being pressed, which its button's style passes down.
    @Environment(\.isHeldDown) private var isHeldDown
    let title: String
    let symbol: ImageResource
    let theme: Theme
    var badge: String?
    var isSelected = false
    var isHovered = false
    /// Its part of the scan is under way.
    var isBusy = false
    /// The sidebar is folded down to a rail, which has room for the glyph alone.
    var isCollapsed = false
    /// The last look at its part left something to do. The rail says so with a dot, in place of the figure.
    var hasFindings = false

    var body: some View {
        let inset = Design.Spacing.small + Design.Spacing.tight / 2
        HStack(spacing: Design.Spacing.medium) {
            SidebarGlyph(symbol: symbol, theme: theme, isSelected: isSelected, isHovered: isHovered,
                         isPressed: isHeldDown, isBusy: isBusy)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(screen.accent)
                        .frame(width: Design.Size.sidebarDot, height: Design.Size.sidebarDot)
                        .offset(x: Design.Spacing.tight / 2, y: -Design.Spacing.hairline)
                        .opacity(isCollapsed && hasFindings ? 1 : 0)
                }
            // The name and the figure stay in place on the rail, unseen, so they fade rather than
            // jump when the sidebar folds and opens out.
            Group {
                Text(title)
                    .font(Design.Typeface.sidebar)
                    .lineLimit(1)
                Spacer(minLength: Design.Spacing.tight)
                if let badge {
                    Text(badge)
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.quiet)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
            }
            .opacity(isCollapsed ? 0 : 1)
            .animation(Design.Motion.sidebarNames, value: isCollapsed)
        }
        .padding(.horizontal, inset)
        // Always laid out as wide as an entry of the open sidebar, so nothing is squeezed or shortened
        // while the sidebar is on its way between the two widths.
        .frame(width: Design.Size.sidebar - inset * 2, height: Design.Size.sidebarRow, alignment: .leading)
        // On the rail the entry is as wide as its glyph and the room around it; the rest is cut off.
        .frame(maxWidth: isCollapsed ? Design.Size.sidebarGlyph + inset * 2 : .infinity, alignment: .leading)
        .clipped()
        .background {
            // Under the pointer the entry stands on the chip the chosen entry has, fainter.
            let isRaised = isSelected || isHovered
            RoundedRectangle(cornerRadius: Design.Radius.control)
                .fill(isSelected ? Design.Surface.selected : isHovered ? Design.Surface.hoverChip : .clear)
                .strokeBorder(isRaised ? Design.Surface.panelBorder : .clear)
                .shadow(color: isRaised ? Design.Surface.shadow : .clear, radius: 6, y: 3)
                .animation(Design.Motion.iconTint, value: isRaised)
        }
        .contentShape(.rect(cornerRadius: Design.Radius.control))
    }
}
