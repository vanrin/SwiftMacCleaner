//
//  FindingCard.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One finding in full: why it can go, the path or command behind it, and every item inside.
struct FindingCard: View {
    @Environment(AppModel.self) private var model
    let finding: Finding
    let active: InUseCheck?

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: Design.Spacing.medium) {
                HStack(spacing: Design.Spacing.medium) {
                    Toggle(sources: model.itemBindings(for: finding), isOn: \.self) {
                        Text(finding.title)
                            .font(Design.Typeface.tileTitle)
                            .lineLimit(1)
                    }
                    .toggleStyle(.check)
                    TierBadge(tier: finding.tier)
                    FindingBadges(finding: finding, active: active)
                    Spacer(minLength: Design.Spacing.medium)
                    SizeLabel(bytes: finding.size, unknown: finding.hasUnknownSize && finding.size == 0)
                }
                Text(finding.explanation)
                    .font(Design.Typeface.tileBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ActionTargetWell(verb: finding.method.verb, target: finding.actionTarget)
                if let note = finding.note {
                    Text(note)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Design.Spacing.large)

            ForEach(finding.items) { item in
                VStack(spacing: 0) {
                    Divider()
                    ItemRow(item: item, finding: finding)
                }
            }
        }
    }
}
