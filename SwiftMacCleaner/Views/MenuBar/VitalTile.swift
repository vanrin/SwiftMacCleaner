//
//  VitalTile.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One reading on the menu bar popover: a ring with the figure in it, the name, and a line. Pressing
/// it opens the reading's details beside the popover, and pressing it again closes them.
struct VitalTile: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    let kind: VitalKind

    var body: some View {
        let summary = model.vitals.readings.summary(of: kind)
        let level = summary?.level ?? .normal
        let isOpen = model.vitals.detail == kind
        Button(action: toggle) {
            GlassPanel(isHighlighted: isOpen, cornerRadius: Design.Radius.tile) {
                VStack(spacing: Design.Spacing.small) {
                    VitalRing(fraction: summary?.fraction ?? 0, level: level, lineWidth: Design.Size.vitalRingLine)
                        .frame(width: Design.Size.vitalRing, height: Design.Size.vitalRing)
                        .overlay {
                            Text(summary?.figure ?? "–")
                                .font(Design.Typeface.vitalFigure)
                                .monospacedDigit()
                        }
                    VStack(spacing: Design.Spacing.tight / 2) {
                        Text(kind.title)
                            .font(.headline)
                        Text(summary?.line ?? "Reading")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(level == .high ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .padding(.horizontal, Design.Spacing.small)
                .frame(maxWidth: .infinity, minHeight: Design.Size.vitalTile)
            }
            .overlay(alignment: .topTrailing) {
                // Colour alone says a reading is raised; the mark says it for anyone who cannot go by colour.
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(level.tint(in: theme))
                    .padding(Design.Spacing.small)
                    .opacity(level == .high || (level == .raised && differentiateWithoutColor) ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect(cornerRadius: Design.Radius.tile))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind.title)
        .accessibilityValue(summary.map { "\($0.figure), \($0.line)" } ?? "Reading")
        .accessibilityAddTraits(isOpen ? .isSelected : [])
        .help(isOpen ? "Hide the \(kind.title) details" : "Show the \(kind.title) details")
    }

    private func toggle() {
        model.vitals.toggle(kind)
    }
}
