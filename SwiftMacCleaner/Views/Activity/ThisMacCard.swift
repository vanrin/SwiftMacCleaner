//
//  ThisMacCard.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The card for the Mac itself: what it is, when the app last cleaned it, and how full its disk is.
struct ThisMacCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    private let mac = MacDescription.current

    var body: some View {
        let disk = model.disk
        let segments = segments(for: disk)
        GlassPanel {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
                    HStack(alignment: .top, spacing: Design.Spacing.medium) {
                        Text("This Mac")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.quiet)
                        Spacer(minLength: 0)
                        cleanedChip
                    }
                    // The chip stands taller than the line it shares, so the name tucks in under it.
                    .frame(height: 16, alignment: .top)
                    Text(mac.name)
                        .font(Design.Typeface.tileTitle)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                    Text(mac.detail)
                        .font(.callout)
                        .foregroundStyle(.quiet)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                MacPicture()
                    .aspectRatio(MacPicture.aspectRatio, contentMode: .fit)
                    .frame(maxWidth: 230)
                    .padding(.vertical, Design.Spacing.medium)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        Ellipse()
                            .fill(EllipticalGradient(colors: [Design.Ground.bloom.opacity(0.9), Design.Ground.bloom.opacity(0)],
                                                     center: .center, startRadiusFraction: 0.1, endRadiusFraction: 0.5))
                    }
                HStack(alignment: .firstTextBaseline, spacing: Design.Spacing.medium) {
                    Text(disk.name)
                        .font(Design.Typeface.rowTitle)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(ByteFormat.string(disk.capacity - disk.free)) of \(ByteFormat.string(disk.capacity)) used")
                        .font(.callout)
                        .foregroundStyle(.quiet)
                        .lineLimit(1)
                }
                UsageBar(segments: segments, total: disk.capacity, height: Design.Size.usageBarHeight)
                    .padding(.top, Design.Spacing.small)
                UsageLegend(segments: segments)
                    .padding(.top, Design.Spacing.small + 2)
            }
            .padding(.horizontal, Design.Spacing.large + Design.Spacing.tight + 2)
            .padding(.vertical, Design.Spacing.large + Design.Spacing.tight)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .contain)
    }

    /// When the app last cleaned anything here, in a small chip at the top right.
    private var cleanedChip: some View {
        let last = model.activity.records.last(where: \.isClean)?.date
        return HStack(spacing: Design.Spacing.tight + 2) {
            Circle()
                .fill(last == nil ? AnyShapeStyle(Color.clear) : AnyShapeStyle(Theme.green.lens))
                .strokeBorder(last == nil ? Design.Ink.tertiary : .clear, lineWidth: 1.5)
                .frame(width: 7, height: 7)
            Text(last.map { "Cleaned \($0.formatted(.relative(presentation: .named)))" } ?? "Not cleaned yet")
                .lineLimit(1)
        }
        .font(.callout.weight(.medium))
        .foregroundStyle(.quiet)
        .padding(.horizontal, Design.Spacing.medium - 2)
        .padding(.vertical, Design.Spacing.tight + 1)
        .background(Design.Surface.well, in: .capsule)
        .fixedSize()
    }

    private func segments(for disk: DiskInfo) -> [UsageSegment] {
        var segments = [UsageSegment(id: "used", label: "Used", bytes: disk.used, color: theme.accent)]
        if disk.purgeable > 0 {
            segments.append(UsageSegment(id: "purgeable", label: "Purgeable", bytes: disk.purgeable,
                                         color: theme.accent, isStriped: true))
        }
        segments.append(UsageSegment(id: "free", label: "Free", bytes: disk.free, color: .clear, isRemainder: true))
        return segments
    }
}
