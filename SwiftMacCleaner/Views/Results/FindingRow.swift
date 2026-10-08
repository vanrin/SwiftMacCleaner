//
//  FindingRow.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One finding on the overview: tick it, see how big it is, or open its area for the items inside.
struct FindingRow: View {
    @Environment(AppModel.self) private var model
    let finding: Finding
    let largest: Int64
    let active: InUseCheck?

    var body: some View {
        HStack(spacing: Design.Spacing.medium) {
            // Shows a dash when only some of the finding's items are ticked.
            Toggle(sources: model.itemBindings(for: finding), isOn: \.self) {
                Text(finding.title)
            }
            .toggleStyle(.checkOnly)

            GlossyIcon(symbol: finding.area.symbol, theme: finding.area.theme)
            VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
                HStack(spacing: Design.Spacing.small) {
                    Text(finding.title)
                        .font(Design.Typeface.rowTitle)
                        .lineLimit(1)
                    FindingBadges(finding: finding, active: active)
                }
                Text(finding.summary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Design.Spacing.medium)

            VStack(alignment: .trailing, spacing: Design.Spacing.tight) {
                SizeLabel(bytes: finding.size, unknown: finding.hasUnknownSize && finding.size == 0)
                SizeBar(fraction: Double(finding.size) / Double(max(largest, 1)),
                        isActive: model.selectedSize(in: finding) > 0)
            }
            Button("Details for \(finding.title)", systemImage: "chevron.right", action: showDetails)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Show what is inside")
        }
        .padding(.horizontal, Design.Spacing.large)
        .padding(.vertical, Design.Spacing.medium)
    }

    private func showDetails() {
        model.select(.area(finding.area))
    }
}
