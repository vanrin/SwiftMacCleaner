//
//  IntroHeading.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// The large title of a screen and the sentence under it.
struct IntroHeading: View {
    let title: String
    let detail: String
    var alignment = HorizontalAlignment.leading

    var body: some View {
        VStack(alignment: alignment, spacing: Design.Spacing.medium) {
            Text(title)
                .font(Design.Typeface.heroTitle)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Text(detail)
                .font(Design.Typeface.heroSubtitle)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(alignment == .center ? .center : .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
