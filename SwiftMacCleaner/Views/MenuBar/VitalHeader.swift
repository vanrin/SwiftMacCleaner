//
//  VitalHeader.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The top of a reading's details: its glyph and name, and a note at the far end.
struct VitalHeader: View {
    @Environment(\.theme) private var theme
    let kind: VitalKind
    /// What stands at the far end: the chip, or the memory this Mac has.
    var note = ""

    var body: some View {
        HStack(spacing: Design.Spacing.medium) {
            FeatureIcon(Image(kind.glyph), theme: theme)
            Text(kind.title)
                .font(Design.Typeface.detailTitle)
            Spacer(minLength: Design.Spacing.medium)
            Text(note)
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.quiet)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
