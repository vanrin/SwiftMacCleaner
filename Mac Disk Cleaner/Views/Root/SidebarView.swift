//
//  SidebarView.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// The column on the left: the overview, the areas that apply to this Mac, and at the bottom the parts
/// of the app that stand apart from the clean-up.
struct SidebarView: View {
    @Environment(AppModel.self) private var model

    private static let developerAreas = Area.allCases.filter(\.isDeveloper)
    private static let systemAreas = Area.allCases.filter { !$0.isDeveloper }

    var body: some View {
        // Areas lead somewhere only once there are results to show.
        let areasAvailable = model.phase == .results || model.phase == .done
        // The entries at the bottom have room of their own. The sidebar has no pane, so a list that
        // scrolled underneath them would show through.
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Design.Spacing.medium) {
                    SidebarButton(item: .overview, title: "Overview", symbol: "sparkles", theme: .violet, badge: overviewBadge)
                    // Only the developer areas this Mac has tools for, so the list reads as its owner's stack.
                    let developerAreas = Self.developerAreas.filter(model.showsInSidebar)
                    if !developerAreas.isEmpty {
                        VStack(spacing: Design.Spacing.tight / 2) {
                            ForEach(developerAreas) { area in
                                SidebarButton(item: .area(area), title: area.title, symbol: area.symbol, theme: area.theme,
                                              badge: badge(for: area), isAvailable: areasAvailable)
                            }
                        }
                    }
                    VStack(spacing: Design.Spacing.tight / 2) {
                        ForEach(Self.systemAreas) { area in
                            SidebarButton(item: .area(area), title: area.title, symbol: area.symbol, theme: area.theme,
                                          badge: badge(for: area), isAvailable: areasAvailable)
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
                SidebarButton(item: .apps, title: "Applications", symbol: "square.grid.2x2", theme: .blue, badge: appsBadge)
                SidebarButton(item: .space, title: "Largest Folders", symbol: "chart.bar.doc.horizontal", theme: .ocean)
                SettingsLink {
                    SidebarLabel(title: "Settings", symbol: "gearshape", theme: .violet)
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

    private func badge(for area: Area) -> String? {
        switch model.areaState(for: area) {
        case .idle: nil
        case .queued: "Queued"
        case .scanning: "Scanning"
        case .skipped: "Skipped"
        case .finished:
            model.foundSize(in: area) > 0 ? ByteFormat.string(model.foundSize(in: area)) : "Clean"
        }
    }
}
