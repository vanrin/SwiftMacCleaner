//
//  HomeView.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// What the app shows before a scan: how full the disk is, what a scan covers, and the button that starts it.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        let disk = model.disk
        let segments = segments(for: disk)
        let nothingTicked = model.enabledAreas.isEmpty
        IntroLayout {
            VStack(spacing: Design.Spacing.xLarge) {
                HeroOrb(segments: segments, total: disk.capacity) {
                    OrbFigure(value: ByteFormat.string(disk.free), caption: "free")
                }
                UsageLegend(segments: segments)
                    .help("Purgeable space holds files macOS frees on its own schedule.")
            }
        } details: {
            VStack(alignment: .leading, spacing: Design.Spacing.medium) {
                if disk.isLow {
                    Badge(text: "Running low", style: .waits)
                }
                IntroHeading(
                    title: disk.name,
                    detail: "\(ByteFormat.string(disk.free)) free of \(ByteFormat.string(disk.capacity)). Scanning only measures, and nothing is removed until you confirm."
                )
            }
            VStack(alignment: .leading, spacing: Design.Spacing.large) {
                FeatureBullet(symbol: "hammer", text: "Build output and caches")
                FeatureBullet(symbol: "shippingbox", text: "Old toolchains, images and models")
                FeatureBullet(symbol: "trash", text: "Installers, leftovers and snapshots")
            }
            HomeOptions()
        }
        .orbAction {
            Button("Scan", action: model.startScan)
                .buttonStyle(.orb)
                .keyboardShortcut(.defaultAction)
                .disabled(nothingTicked)
                .accessibilityLabel("Scan \(disk.name)")
                .help("Scan \(disk.name). About a minute.")
        }
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
