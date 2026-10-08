//
//  DropdownButtonStyle.swift
//  SwiftMacCleaner
//

import SwiftUI

/// A glass field with a chevron at its end, for a button that opens a list of choices.
struct DropdownButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Design.Spacing.medium) {
            configuration.label
                .font(Design.Typeface.tileBody)
                .bold()
                .lineLimit(1)
            Spacer(minLength: Design.Spacing.small)
            Image(systemName: "chevron.down")
                .font(.callout)
                .bold()
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Design.Spacing.large)
        .padding(.vertical, Design.Spacing.medium)
        .frame(width: Design.Size.dropdownWidth)
        .background {
            RoundedRectangle(cornerRadius: Design.Radius.control)
                .fill(configuration.isPressed ? Design.Surface.quietButton : Design.Surface.well)
                .strokeBorder(Design.Surface.panelBorder)
        }
        .contentShape(.rect(cornerRadius: Design.Radius.control))
        .animation(Design.Motion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == DropdownButtonStyle {
    static var dropdown: DropdownButtonStyle { DropdownButtonStyle() }
}
