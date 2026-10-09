//
//  SidebarView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The column on the left: the overview and the clean-ups it runs, and at the bottom the other parts
/// of the app. Every entry leads somewhere at any time.
struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        // The entries at the bottom have room of their own. The sidebar has no pane, so a list that
        // scrolled underneath them would show through.
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Design.Spacing.medium) {
                    SidebarButton(item: .overview, badge: overviewBadge)
                    VStack(spacing: Design.Spacing.tight / 2) {
                        ForEach(model.cleanUpEntries, id: \.self) { item in
                            SidebarButton(item: item, badge: badge(for: item))
                        }
                    }
                }
                .padding(.horizontal, Design.Spacing.small + Design.Spacing.tight / 2)
                .padding(.vertical, Design.Spacing.small)
            }
            .scrollIndicators(.never)
            // The last entry in view fades out instead of being cut off.
            .mask {
                VStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: Design.Spacing.large)
                }
            }
            VStack(spacing: Design.Spacing.tight / 2) {
                SidebarButton(item: .performance, badge: performanceBadge)
                SidebarButton(item: .apps, badge: appsBadge)
                SidebarButton(item: .space)
                SettingsLink {
                    SidebarLabel(title: "Settings", glyph: .glyphSettings, theme: .violet)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Design.Spacing.small + Design.Spacing.tight / 2)
            .padding(.vertical, Design.Spacing.medium)
        }
    }

    /// How many apps the last look found, once there has been one.
    private var appsBadge: String? {
        switch model.apps.phase {
        case .idle: nil
        case .scanning: "Scanning"
        case .summary, .managing, .removing, .done: model.apps.apps.count.formatted()
        }
    }

    /// How many tasks the last look found worth running, once there has been one.
    private var performanceBadge: String? {
        switch model.performance.phase {
        case .idle: nil
        case .scanning: "Scanning"
        case .summary, .managing, .running, .done:
            model.performance.recommended.isEmpty ? "Fine" : "\(model.performance.recommended.count) to run"
        }
    }

    /// What the clean-ups have found between them, while the overview has a scan to show.
    private var overviewBadge: String? {
        switch model.overviewPhase {
        case .scanning, .results, .running, .done:
            model.foundSize > 0 ? ByteFormat.string(model.foundSize) : nil
        case .home:
            nil
        }
    }

    /// What a clean-up's last scan found, once there has been one.
    private func badge(for item: SidebarItem) -> String? {
        guard case .group(let group) = item else { return nil }
        let cleanUp = model.cleanUp(group)
        return switch cleanUp.phase {
        case .home: nil
        case .scanning: "Scanning"
        case .results, .cleaning, .done: cleanUp.foundSize > 0 ? ByteFormat.string(cleanUp.foundSize) : "Clean"
        }
    }
}
