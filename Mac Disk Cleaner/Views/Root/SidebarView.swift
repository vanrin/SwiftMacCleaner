//
//  SidebarView.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// The column on the left: the overview, every area the scan knows, and at the bottom the parts of the
/// app that stand apart from the clean-up.
struct SidebarView: View {
    @Environment(AppModel.self) private var model

    private static let developerAreas = Area.allCases.filter(\.isDeveloper)
    private static let systemAreas = Area.allCases.filter { !$0.isDeveloper }

    var body: some View {
        // Areas lead somewhere only once there are results to show.
        let areasAvailable = model.phase == .results || model.phase == .done
        ScrollView {
            VStack(spacing: Design.Spacing.medium) {
                SidebarButton(item: .overview, title: "Overview", symbol: "sparkles", theme: .violet, badge: overviewBadge)
                VStack(spacing: Design.Spacing.tight / 2) {
                    ForEach(Self.developerAreas) { area in
                        SidebarButton(item: .area(area), title: area.title, symbol: area.symbol, theme: area.theme,
                                      badge: badge(for: area), isAvailable: areasAvailable)
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: Design.Spacing.tight / 2) {
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
