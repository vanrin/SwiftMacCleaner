//
//  TierBadge.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// "Safe", "Review" or "Careful", always spelled out so colour is never the only signal.
struct TierBadge: View {
    @Environment(\.theme) private var theme
    let tier: SafetyTier

    var body: some View {
        Text(tier.label)
            .font(.callout)
            .bold()
            .padding(.horizontal, Design.Spacing.small)
            .padding(.vertical, Design.Spacing.tight / 2)
            .foregroundStyle(tier == .careful ? theme.deep : tier.color)
            .background(tier.color.opacity(tier == .careful ? 0.92 : 0.2), in: .capsule)
    }
}
