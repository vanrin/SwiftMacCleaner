//
//  ProtectedRow.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One thing the scan left alone, with the rule that kept it.
struct ProtectedRow: View {
    let item: ProtectedItem

    var body: some View {
        HStack(spacing: Design.Spacing.medium) {
            TitledDetail(title: item.title, detail: item.why)
            Spacer(minLength: Design.Spacing.medium)
            Badge(text: item.rule.rawValue, style: .neutral)
            Text(item.size.map(ByteFormat.string) ?? "kept")
                .font(Design.Typeface.tileBody)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: Design.Size.sizeColumn, alignment: .trailing)
        }
        .padding(.horizontal, Design.Spacing.large)
        .padding(.vertical, Design.Spacing.small)
    }
}
