//
//  HomeView.swift
//  SwiftMacCleaner
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
                HeroMac {
                    VStack(spacing: Design.Spacing.medium) {
                        OrbFigure(value: ByteFormat.string(disk.free), caption: "free")
                        UsageBar(segments: segments, total: disk.capacity, height: Design.Size.usageBarHeight)
                    }
                }
                UsageLegend(segments: segments)
                    .help("Purgeable space holds files macOS frees on its own schedule.")
            }
            // The Mac fills the room it is given, so it is held clear of the text beside it.
            .padding(.trailing, Design.Spacing.xLarge)
        } details: {
            VStack(alignment: .leading, spacing: Design.Spacing.medium) {
                if disk.isLow {
                    Badge(text: "Running low", style: .waits)
                }
                IntroHeading(
                    title: disk.name,
                    detail: "\(ByteFormat.string(disk.free)) free of \(ByteFormat.string(disk.capacity)). One scan runs every part of the app, shows everything that can go, and selects the part worth cleaning now."
                )
            }
            // One scan runs every part of the app; each part's own entry runs it alone.
            VStack(alignment: .leading, spacing: Design.Spacing.large) {
                FeatureBullet(glyph: Image(.glyphSystem), text: "Junk from macOS, your apps and developer tools")
                FeatureBullet(glyph: Image(.glyphApps), text: "Apps, their updates and what they left behind")
                FeatureBullet(glyph: Image(.glyphPerformance), text: "Maintenance tasks, login and background items")
            }
            HomeOptions()
        }
        .orbAction {
            Button("Scan", action: model.startScan)
                .buttonStyle(.orb)
                .keyboardShortcut(.defaultAction)
                .disabled(nothingTicked)
                .accessibilityLabel("Scan \(disk.name)")
                .help("Run every part's scan on \(disk.name). About a minute.")
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
