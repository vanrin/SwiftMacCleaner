//
//  AppsColumnRow.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// One choice in the manager's column: a part of the manager, or a filter, with how much is in it.
struct AppsColumnRow: View {
    let title: String
    let value: String
    let isSelected: Bool
    /// The three parts of the manager are set larger than the filters under them.
    var isProminent = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Design.Spacing.small) {
                Text(title)
                    .font(isProminent ? Design.Typeface.rowTitle : Design.Typeface.sidebar)
                    .lineLimit(1)
                Spacer(minLength: Design.Spacing.small)
                Text(value)
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, Design.Spacing.medium)
            .frame(height: isProminent ? Design.Size.sidebarRow : Design.Size.sidebarRow - Design.Spacing.small)
            .background {
                RoundedRectangle(cornerRadius: Design.Radius.control)
                    .fill(isSelected ? Design.Surface.quietButton : isHovered ? Design.Surface.hover : .clear)
                    .strokeBorder(isSelected ? Design.Surface.panelBorder : .clear)
            }
            .contentShape(.rect(cornerRadius: Design.Radius.control))
        }
        .buttonStyle(.plain)
        .onHover(perform: hover)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func hover(_ isInside: Bool) {
        isHovered = isInside
    }
}
