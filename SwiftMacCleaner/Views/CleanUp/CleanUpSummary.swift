//
//  CleanUpSummary.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What a clean-up found: how much can go, a way into the manager, and a tile for each area with
/// something in it. The largest area stands tall on the left; the others share the right.
struct CleanUpSummary: View {
    @Environment(AppModel.self) private var model
    @Environment(CleanUpModel.self) private var cleanUp

    var body: some View {
        let group = cleanUp.group
        let found = cleanUp.areas.filter { !cleanUp.findings(in: $0).isEmpty }
            .sorted { cleanUp.foundSize(in: $0) > cleanUp.foundSize(in: $1) }
        let quiet = model.areas(in: group).filter { cleanUp.findings(in: $0).isEmpty }
        ScrollView {
            VStack(alignment: .leading, spacing: Design.Spacing.section) {
                VStack(spacing: Design.Spacing.large) {
                    Text(headline(found))
                        .font(Design.Typeface.headline)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(detail(found))
                        .font(Design.Typeface.tileBody)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 640)
                    if let largest = found.first {
                        Button("Review All") { open(largest) }
                            .buttonStyle(.primaryPill)
                        FreeSpaceForecast(now: model.disk.free, after: model.disk.free + cleanUp.selectedSize)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Design.Spacing.medium)

                if let largest = found.first {
                    let rest = Array(found.dropFirst())
                    HStack(alignment: .top, spacing: Design.Spacing.large) {
                        tile(for: largest, height: Design.Size.tileHeight * Double(max(rest.count, 1))
                             + Design.Spacing.large * Double(max(rest.count - 1, 0)))
                        if !rest.isEmpty {
                            VStack(spacing: Design.Spacing.large) {
                                ForEach(rest) { area in
                                    tile(for: area, height: Design.Size.tileHeight)
                                }
                            }
                        }
                    }
                }
                if !quiet.isEmpty {
                    QuietAreasPanel(areas: quiet, open: open)
                }
                if !cleanUp.unreadableFolders.isEmpty {
                    FullDiskAccessNote(folders: cleanUp.unreadableFolders)
                }
            }
            .pageLayout()
        }
        .orbAction {
            if !found.isEmpty {
                CleanButton(size: cleanUp.selectedSize, hasUnknownSize: cleanUp.selectionHasUnknownSize) {
                    cleanUp.review()
                }
            }
        }
    }

    private func tile(for area: Area, height: Double) -> some View {
        let selected = cleanUp.selectedSize(in: area)
        let findings = cleanUp.findings(in: area)
        return SummaryTile(
            title: "\(ByteFormat.string(cleanUp.foundSize(in: area))) in \(area.title)",
            detail: tileDetail(area, selected: selected),
            glyph: area.glyph,
            tiers: SafetyTier.allCases.filter { tier in findings.contains { $0.tier == tier } },
            primaryTitle: selected > 0 || cleanUp.selectionHasUnknownSize(in: area) ? "Clean" : nil,
            primaryAction: { cleanUp.review(area: area) },
            height: height
        ) {
            open(area)
        }
    }

    private func headline(_ found: [Area]) -> String {
        found.isEmpty
            ? "Nothing to clean in \(cleanUp.group.scope)"
            : "\(ByteFormat.string(cleanUp.foundSize)) found in \(cleanUp.group.scope)"
    }

    private func detail(_ found: [Area]) -> String {
        guard !found.isEmpty else {
            return "The scan found nothing worth removing right now."
        }
        var text = "\(ByteFormat.string(cleanUp.selectedSize)) of it is ticked. Rebuildable items are deleted right away; everything else goes to the Trash first and can be put back."
        if !cleanUp.protected.isEmpty {
            text += " \(ByteFormat.string(cleanUp.protectedSize)) more was left alone on purpose."
        }
        return text
    }

    /// What is in the area, by the names of its findings, and how much of it is ticked.
    private func tileDetail(_ area: Area, selected: Int64) -> String {
        let names = cleanUp.findings(in: area).map(\.title).formatted(.list(type: .and, width: .narrow))
        let ticked = selected > 0 ? "\(ByteFormat.string(selected)) of it is ticked." : "Nothing here is ticked for you."
        return "\(names). \(ticked)"
    }

    private func open(_ area: Area) {
        cleanUp.open(area)
    }
}
