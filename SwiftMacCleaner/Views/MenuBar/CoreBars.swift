//
//  CoreBars.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Every core of the processor as a bar, the fast ones and the frugal ones each in a group of their own.
struct CoreBars: View {
    let groups: [CoreGroup]

    var body: some View {
        let width = barWidth
        HStack(alignment: .bottom, spacing: Design.Spacing.large) {
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: Design.Spacing.tight) {
                    HStack(alignment: .bottom, spacing: Design.Size.coreBarSpacing) {
                        ForEach(group.cores) { core in
                            CoreBar(load: core.load, width: width)
                        }
                    }
                    Text(group.caption)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(group.caption)
                .accessibilityValue("Busiest at \(VitalFormat.percent(group.busiest)), \(VitalFormat.percent(group.average)) on average")
            }
        }
        .frame(maxWidth: .infinity, minHeight: Design.Size.coreBarHeight, alignment: .leading)
    }

    /// A chip with many cores gets thinner bars, so that all of them fit across the panel.
    private var barWidth: Double {
        let cores = groups.reduce(0) { $0 + $1.cores.count }
        guard cores > 0 else { return Design.Size.coreBarWidth }
        let room = Design.Size.menuBarWidth - 2 * Design.Spacing.large
            - Double(groups.count - 1) * Design.Spacing.large
            - Double(cores - groups.count) * Design.Size.coreBarSpacing
        return min(Design.Size.coreBarWidth, max(Design.Size.coreBarMinimum, (room / Double(cores)).rounded(.down)))
    }
}
