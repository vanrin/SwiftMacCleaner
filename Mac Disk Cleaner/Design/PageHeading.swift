//
//  PageHeading.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// The top of a page that is mostly a list: a large title on the left and a sentence that sums the page up.
struct PageHeading: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.small) {
            Text(title)
                .font(Design.Typeface.heroTitle)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(detail)
                .font(Design.Typeface.heroSubtitle)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
