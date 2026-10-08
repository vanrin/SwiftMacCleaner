//
//  AreaToggleRow.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One area the scan can look at, with a box to tick.
struct AreaToggleRow: View {
    @Environment(AppModel.self) private var model
    let area: Area

    var body: some View {
        Toggle(isOn: model.binding(for: area)) {
            HStack(spacing: Design.Spacing.medium) {
                GlossyIcon(symbol: area.symbol, theme: area.theme)
                VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
                    HStack(spacing: Design.Spacing.small) {
                        Text(area.title)
                            .font(.headline)
                            .lineLimit(1)
                        if area.isNew {
                            Badge(text: "New", style: .new)
                        }
                    }
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
        }
        .toggleStyle(.check)
        .padding(.horizontal, Design.Spacing.large)
        .padding(.vertical, Design.Spacing.small)
    }

    /// What was found on this Mac for the area, or what the area covers when nothing has a name.
    private var detail: String {
        model.stack.summary(of: area).map { "On this Mac: \($0)" } ?? area.summary
    }
}
