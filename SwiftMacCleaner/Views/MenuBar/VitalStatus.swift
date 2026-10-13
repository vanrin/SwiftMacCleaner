//
//  VitalStatus.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The word that sums a reading up, with a sentence under it.
struct VitalStatus: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.tight) {
            Text(title)
                .font(Design.Typeface.detailTitle)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
