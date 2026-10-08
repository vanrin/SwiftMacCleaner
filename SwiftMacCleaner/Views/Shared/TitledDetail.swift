//
//  TitledDetail.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Two lines of text: a title, and a quieter line under it. The building block of most rows.
struct TitledDetail: View {
    let title: String
    let detail: String
    /// How many lines the detail may take before it is cut short. `nil` lets it wrap freely.
    var detailLineLimit: Int? = 1

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
            Text(title)
                .font(Design.Typeface.rowTitle)
                .lineLimit(1)
            Text(detail)
                .foregroundStyle(.secondary)
                .lineLimit(detailLineLimit)
                .truncationMode(.middle)
                .fixedSize(horizontal: false, vertical: detailLineLimit == nil)
        }
    }
}
