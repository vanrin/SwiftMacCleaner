//
//  OverviewSummary.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What every part found, as one tile each with a box to tick, and the round button that runs the
/// ticked ones: each clean-up cleans what is ticked in it, and Performance runs its recommended tasks.
struct OverviewSummary: View {
    @Environment(AppModel.self) private var model

    private let columns = [GridItem(.adaptive(minimum: Design.Size.tileMinimum), spacing: Design.Spacing.large)]

    var body: some View {
        let parts = model.overviewParts
        let runs = parts.filter { model.included.contains($0) && model.hasWork($0) }
        ScrollView {
            VStack(alignment: .leading, spacing: Design.Spacing.section) {
                VStack(spacing: Design.Spacing.large) {
                    Text(headline(runs))
                        .font(Design.Typeface.headline)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(detail(runs))
                        .font(Design.Typeface.tileBody)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 640)
                    if model.runSize > 0 {
                        FreeSpaceForecast(now: model.disk.free, after: model.disk.free + model.runSize)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Design.Spacing.medium)

                LazyVGrid(columns: columns, spacing: Design.Spacing.large) {
                    ForEach(parts, id: \.self) { part in
                        OverviewTile(part: part)
                    }
                }
                if !model.unreadableFolders.isEmpty {
                    FullDiskAccessNote(folders: model.unreadableFolders)
                }
            }
            .pageLayout()
        }
        .orbAction {
            if parts.contains(where: model.hasWork) {
                CleanButton(title: "Run", size: model.runSize, hasUnknownSize: model.runHasUnknownSize,
                            isEnabled: !runs.isEmpty, action: model.reviewRun)
            }
        }
    }

    private func headline(_ runs: [SidebarItem]) -> String {
        if model.overviewParts.contains(where: model.hasWork) {
            return runs.isEmpty ? "Nothing is ticked to run" : "Everything is ready to run"
        }
        return "Nothing needs doing right now"
    }

    private func detail(_ runs: [SidebarItem]) -> String {
        guard model.overviewParts.contains(where: model.hasWork) else {
            return "The scan found nothing worth removing and no task worth running. Each part still shows what it looked at."
        }
        var text = "Tick what Run should do, or open a part to choose item by item."
        if runs.contains(.performance) {
            text += " The maintenance tasks that need root ask for your password once."
        }
        return text
    }
}
