//
//  ProtectedList.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// What the scan found and deliberately left alone, with the rule that kept each item.
struct ProtectedList: View {
    var title = "Protected on purpose"
    var subtitle = "Found, but left alone because a rule says so. Nothing here can be ticked."
    let items: [ProtectedItem]

    var body: some View {
        GlassPanel {
            HStack(spacing: Design.Spacing.medium) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                TitledDetail(title: title, detail: subtitle)
                Spacer(minLength: Design.Spacing.medium)
                SizeLabel(bytes: items.reduce(0) { $0 + ($1.size ?? 0) })
            }
            .padding(Design.Spacing.large)

            ForEach(items) { item in
                VStack(spacing: 0) {
                    Divider()
                    ProtectedRow(item: item)
                }
            }
        }
    }
}
