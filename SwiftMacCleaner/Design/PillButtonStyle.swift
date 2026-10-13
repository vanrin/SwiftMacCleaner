//
//  PillButtonStyle.swift
//  SwiftMacCleaner
//

import SwiftUI

/// A capsule button: solid white for the action a panel leads to, see-through for the quieter one beside it.
struct PillButtonStyle: ButtonStyle {
    enum Kind {
        case primary, quiet
    }

    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    var kind = Kind.quiet
    /// For a button in a row of a list, where the usual pill would stand taller than the row's text.
    var isCompact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isCompact ? .callout : Design.Typeface.tileBody)
            .bold()
            .lineLimit(1)
            .padding(.horizontal, isCompact ? Design.Spacing.medium : Design.Spacing.large)
            .padding(.vertical, isCompact ? Design.Spacing.tight : Design.Spacing.small)
            .foregroundStyle(kind == .primary ? AnyShapeStyle(theme.deep) : AnyShapeStyle(.white))
            .background(kind == .primary ? AnyShapeStyle(.white) : AnyShapeStyle(Design.Surface.quietButton), in: .capsule)
            .contentShape(.capsule)
            .brightness(configuration.isPressed ? -0.12 : 0)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(Design.Motion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static var pill: PillButtonStyle { PillButtonStyle() }
    static var primaryPill: PillButtonStyle { PillButtonStyle(kind: .primary) }
    static var compactPill: PillButtonStyle { PillButtonStyle(isCompact: true) }
}
