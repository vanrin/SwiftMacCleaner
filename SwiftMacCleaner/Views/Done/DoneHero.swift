//
//  DoneHero.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The top of the result: what the disk gained, measured on the disk itself.
struct DoneHero: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let outcome: CleanOutcome

    var body: some View {
        let segments = [
            UsageSegment(id: "keep", label: "Keeping", bytes: max(0, model.disk.used - model.foundSize), color: Design.Surface.keeping),
            UsageSegment(id: "found", label: "Still removable", bytes: model.foundSize, color: theme.accent),
            UsageSegment(id: "free", label: "Free now", bytes: model.disk.free, color: .clear, isRemainder: true),
        ]
        GlassPanel {
            HStack(spacing: Design.Spacing.section) {
                HeroOrb(segments: segments, total: model.disk.capacity, size: Design.Size.compactOrb) {
                    Image(systemName: "checkmark")
                        .font(Design.Typeface.orbFigure)
                        .accessibilityLabel("Done")
                }
                VStack(alignment: .leading, spacing: Design.Spacing.xLarge) {
                    IntroHeading(title: "Clean-up complete", detail: detail)
                    UsageLegend(segments: segments)
                    if model.findings.isEmpty {
                        Button("Done", action: model.showResults)
                            .buttonStyle(.primaryPill)
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Design.Spacing.section)
        }
    }

    private var detail: String {
        let seconds = Int(outcome.duration.rounded())
        let took = seconds >= 60 ? "\(seconds / 60) min \(seconds % 60) s" : "\(seconds) s"
        return "\(ByteFormat.string(outcome.reclaimed)) reclaimed. Free space went from \(ByteFormat.string(outcome.freeBefore)) to \(ByteFormat.string(outcome.freeAfter)), measured on the disk, in \(took)."
    }
}
