//
//  Badge.swift
//  SwiftMacCleaner
//

import SwiftUI

/// A short label next to a title: what a row waits for, whether it needs a password, that it is new,
/// what removing it leaves you with, or how much of it is ticked.
struct Badge: View {
    enum Style {
        case waits, password, new, neutral
        /// How much of something is ticked.
        case selected
    }

    @Environment(\.theme) private var theme
    let text: String
    var style: Style = .neutral

    var body: some View {
        Text(text)
            .font(.callout)
            .bold()
            .lineLimit(1)
            .padding(.horizontal, Design.Spacing.small)
            .padding(.vertical, Design.Spacing.tight / 2)
            .foregroundStyle(foreground)
            .background(background, in: .capsule)
    }

    private var foreground: AnyShapeStyle {
        switch style {
        case .waits: AnyShapeStyle(Design.Signal.review)
        case .password: AnyShapeStyle(theme.deep)
        case .new, .selected: AnyShapeStyle(theme.accent)
        case .neutral: AnyShapeStyle(.primary)
        }
    }

    private var background: Color {
        switch style {
        case .waits: Design.Signal.review.opacity(0.2)
        case .password: .white.opacity(0.92)
        case .new, .selected: theme.accent.opacity(0.22)
        case .neutral: Design.Surface.well
        }
    }
}
