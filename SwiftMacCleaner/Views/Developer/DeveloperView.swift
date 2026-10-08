//
//  DeveloperView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Developer Clean Up: what the scan found in each developer area, with the way into every one of them,
/// and under that the areas it had nothing to offer in.
struct DeveloperView: View {
    @Environment(AppModel.self) private var model

    private let columns = [GridItem(.adaptive(minimum: Design.Size.tileMinimum), spacing: Design.Spacing.large)]

    var body: some View {
        let areas = model.developerAreas
        // Largest first, as on the overview.
        let found = areas.filter { !model.findings(in: $0).isEmpty }
            .sorted { model.foundSize(in: $0) > model.foundSize(in: $1) }
        let quiet = areas.filter { model.findings(in: $0).isEmpty }
        ScrollView {
            VStack(alignment: .leading, spacing: Design.Spacing.section) {
                PageHeading(title: SidebarItem.developer.title, detail: detail(found))
                if !found.isEmpty {
                    LazyVGrid(columns: columns, spacing: Design.Spacing.large) {
                        ForEach(found) { area in
                            ResultTile(item: .area(area))
                        }
                    }
                }
                if !quiet.isEmpty {
                    QuietAreasPanel(areas: quiet)
                }
            }
            .pageLayout()
        }
        .orbAction {
            if !found.isEmpty {
                CleanButton()
            }
        }
    }

    private func detail(_ found: [Area]) -> String {
        guard !found.isEmpty else {
            return "The scan found nothing worth removing in the developer areas on this Mac."
        }
        let areas = found.count == 1 ? "1 area" : "\(found.count) areas"
        return "\(ByteFormat.string(model.foundSize(under: .developer))) found in \(areas), "
            + "\(ByteFormat.string(model.selectedSize(under: .developer))) of it selected."
    }
}
