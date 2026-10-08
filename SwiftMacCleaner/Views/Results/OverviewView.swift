//
//  OverviewView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The scan results: what was found in each area, then every finding grouped by how safe it is to remove.
struct OverviewView: View {
    @Environment(AppModel.self) private var model

    private let columns = [GridItem(.adaptive(minimum: Design.Size.tileMinimum), spacing: Design.Spacing.large)]

    var body: some View {
        let groups = Dictionary(grouping: model.findings, by: \.tier)
        let largest = model.findings.map(\.size).max() ?? 1
        let active = model.activeChecks()
        ScrollView {
            VStack(alignment: .leading, spacing: Design.Spacing.section) {
                if model.findings.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing to reclaim", systemImage: "checkmark.circle")
                    } description: {
                        Text("The scan found nothing worth removing in the areas it looked at.")
                    }
                } else {
                    ResultsHeadline()
                    LazyVGrid(columns: columns, spacing: Design.Spacing.large) {
                        ForEach(model.largestAreas(Area.allCases.count), id: \.area) { entry in
                            ResultTile(area: entry.area, size: entry.size)
                        }
                    }
                    SectionHeading(
                        title: "Everything found, by how safe it is to remove",
                        detail: "Tick or untick a whole group here, or open its area to choose item by item."
                    )
                }
                ForEach(SafetyTier.allCases.filter { groups[$0] != nil }, id: \.self) { tier in
                    TierSection(tier: tier, findings: groups[tier] ?? [], largest: largest, active: active)
                }
                if !model.protected.isEmpty {
                    ProtectedList(items: model.protected)
                }
                if !model.findings.isEmpty, !model.unreadableFolders.isEmpty {
                    FullDiskAccessNote()
                }
            }
            .pageLayout()
        }
        .orbAction {
            if !model.findings.isEmpty {
                CleanButton()
            }
        }
    }
}
