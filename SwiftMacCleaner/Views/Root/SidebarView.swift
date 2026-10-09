//
//  SidebarView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The column on the left: the overview and what the clean-up is filed under, and at the bottom the
/// parts of the app that stand apart from the clean-up.
struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        // Areas lead somewhere only once there are results to show.
        let areasAvailable = model.phase == .results || model.phase == .done
        // The entries at the bottom have room of their own. The sidebar has no pane, so a list that
        // scrolled underneath them would show through.
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Design.Spacing.medium) {
                    SidebarButton(item: .overview, badge: overviewBadge)
                    VStack(spacing: Design.Spacing.tight / 2) {
                        // One entry for each group, however many areas it holds.
                        ForEach(model.cleanUpEntries, id: \.self) { item in
                            SidebarButton(item: item, badge: badge(for: item), isAvailable: areasAvailable)
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

    private var overviewBadge: String? {
        switch model.phase {
        case .scanning, .results, .done:
            model.foundSize > 0 ? ByteFormat.string(model.foundSize) : nil
        case .home, .cleaning:
            nil
        }
    }

    private func badge(for item: SidebarItem) -> String? {
        let found = model.foundSize(under: item)
        return switch model.state(of: item) {
        case .idle: nil
        case .queued: "Queued"
        case .scanning: "Scanning"
        case .skipped: "Skipped"
        case .finished: found > 0 ? ByteFormat.string(found) : "Clean"
        }
    }
}
