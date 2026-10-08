//
//  TierSection.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// Every finding of one safety tier, under a heading that says what the tier means.
struct TierSection: View {
    let tier: SafetyTier
    let findings: [Finding]
    let largest: Int64
    let active: [String: InUseCheck]

    var body: some View {
        GlassPanel {
            HStack(spacing: Design.Spacing.medium) {
                TierBadge(tier: tier)
                TitledDetail(title: tier.headline, detail: tier.explanation, detailLineLimit: 2)
                Spacer(minLength: Design.Spacing.medium)
                SizeLabel(bytes: findings.reduce(0) { $0 + $1.size })
            }
            .padding(Design.Spacing.large)

            ForEach(findings) { finding in
                VStack(spacing: 0) {
                    Divider()
                    FindingRow(finding: finding, largest: largest, active: active[finding.id])
                }
            }
        }
    }
}
