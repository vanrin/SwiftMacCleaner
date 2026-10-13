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
        case .password: AnyShapeStyle(.white)
        // The accent is too pale for small type, so it tints the capsule and the words stay in ink.
        case .new, .selected: AnyShapeStyle(Design.Ink.primary)
        case .neutral: AnyShapeStyle(.primary)
        }
    }

    private var background: Color {
        switch style {
        case .waits: Design.Signal.review.opacity(0.2)
        case .password: Design.Ink.primary.opacity(0.88)
        case .new, .selected: theme.accent.opacity(0.24)
        case .neutral: Design.Surface.well
        }
    }
}
