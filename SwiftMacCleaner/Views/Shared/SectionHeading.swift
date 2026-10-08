//
//  SectionHeading.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The title of a section of a page and the sentence that explains it.
struct SectionHeading: View {
    let title: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
            Text(title)
                .font(Design.Typeface.tileTitle)
            if let detail {
                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
