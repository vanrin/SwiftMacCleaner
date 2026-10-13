//
//  MemoryComposition.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What the Mac's memory is taken up by: one bar split into its parts, and what each part comes to.
struct MemoryComposition: View {
    @Environment(\.theme) private var theme
    let reading: MemoryReading

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.medium) {
            UsageBar(segments: [
                UsageSegment(id: "active", label: "Active", bytes: reading.active, color: theme.accent),
                UsageSegment(id: "wired", label: "Wired", bytes: reading.wired, color: Design.Surface.secondShare),
                UsageSegment(id: "compressed", label: "Compressed", bytes: reading.compressed, color: theme.faintAccent),
            ], total: reading.total)
            Grid(horizontalSpacing: Design.Spacing.large, verticalSpacing: Design.Spacing.tight) {
                GridRow {
                    VitalLegendItem(label: "Active", value: VitalFormat.memory(reading.active), color: theme.accent)
                    VitalLegendItem(label: "Wired", value: VitalFormat.memory(reading.wired), color: Design.Surface.secondShare)
                }
                GridRow {
                    VitalLegendItem(label: "Compressed", value: VitalFormat.memory(reading.compressed), color: theme.faintAccent)
                    VitalLegendItem(label: "Available", value: VitalFormat.memory(reading.available), isRemainder: true)
                }
            }
        }
    }
}
