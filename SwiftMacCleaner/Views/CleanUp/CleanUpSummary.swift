//
//  CleanUpSummary.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What a clean-up found: all of it in the headline, how much of that is ticked, a way into the
/// manager, and a tile for each area with something in it. The largest area stands tall on the left;
/// the others share the right.
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
                        // Side by side where there is room, the way in above the figures where there is not.
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: Design.Spacing.medium) {
                                reviewButton(opening: largest)
                                forecast
                                selectionMenu
                            }
                            VStack(spacing: Design.Spacing.large) {
                                reviewButton(opening: largest)
                                HStack(spacing: Design.Spacing.medium) {
                                    forecast
                                    selectionMenu
                                }
                            }
                        }
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
                CleanButton(size: cleanUp.cleanableSize(), hasUnknownSize: cleanUp.selectionHasUnknownSize) {
                    cleanUp.review()
                }
            }
        }
    }

    private func reviewButton(opening area: Area) -> some View {
        Button(cleanUp.group.holdsJunk ? "Review All Junk" : "Review All") { open(area) }
            .buttonStyle(.primaryPill)
    }

    private var forecast: some View {
        FreeSpaceForecast(now: model.disk.free, after: model.disk.free + cleanUp.cleanableSize())
    }

    private var selectionMenu: some View {
        SelectionMenu(preset: cleanUp.preset()) { cleanUp.select($0) }
    }

    private func tile(for area: Area, height: Double) -> some View {
        let selected = cleanUp.selectedSize(in: area)
        let findings = cleanUp.findings(in: area)
        return SummaryTile(
            title: "\(ByteFormat.string(cleanUp.foundSize(in: area))) in \(area.title)",
            detail: findings.map(\.title).formatted(.list(type: .and, width: .narrow)) + ".",
            glyph: area.glyph,
            badges: badges(for: area, findings: findings, selected: selected),
            primaryTitle: selected > 0 || cleanUp.selectionHasUnknownSize(in: area) ? "Clean" : nil,
            primaryAction: { cleanUp.review(area: area) },
            height: height
        ) {
            open(area)
        }
    }

    /// How much of the area is ticked, what removing its groups leaves you with, and how much of
    /// what is ticked needs a password.
    private func badges(for area: Area, findings: [Finding], selected: Int64) -> [TileBadge] {
        let found = cleanUp.foundSize(in: area)
        var badges = [TileBadge(
            text: selected == 0 ? "Nothing selected" : selected >= found ? "All selected" : "\(ByteFormat.string(selected)) selected",
            style: selected > 0 ? .selected : .neutral
        )]
        badges += Set(findings.map(\.aftermath)).sorted().map { TileBadge(text: $0.label) }
        let behindPassword = findings.filter(\.method.needsPassword).reduce(Int64(0)) { $0 + cleanUp.selectedSize(in: $1) }
        if behindPassword > 0 {
            badges.append(TileBadge(text: "Password for \(ByteFormat.string(behindPassword))", style: .password))
        }
        return badges
    }

    private func headline(_ found: [Area]) -> String {
        let group = cleanUp.group
        guard !found.isEmpty else { return "Nothing to clean in \(group.scope)" }
        let size = ByteFormat.string(cleanUp.foundSize)
        return group.holdsJunk ? "\(size) of junk found" : "\(size) found in \(group.scope)"
    }

    private func detail(_ found: [Area]) -> String {
        guard !found.isEmpty else {
            return "The scan found nothing worth removing right now."
        }
        let selected = cleanUp.selectedSize
        var text = if selected == 0, !cleanUp.selectionHasUnknownSize {
            "Nothing is selected. Tick what you want gone, or open an area to choose row by row."
        } else {
            "\(ByteFormat.string(selected)) of it is selected\(cleanUp.preset() == .smart ? " for you" : "")."
        }
        text += " " + cleanUp.group.removalSentence
        let waiting = cleanUp.waitingSize()
        if waiting > 0 {
            let apps = cleanUp.blockingApps().map(\.app.name)
            let names = apps.isEmpty ? "something that is running" : ListFormat.string(apps)
            text += " \(ByteFormat.string(waiting)) of it waits for \(names) to quit, which the confirmation offers."
        }
        if !cleanUp.protected.isEmpty {
            text += " \(ByteFormat.string(cleanUp.protectedSize)) more was left alone on purpose."
        }
        return text
    }

    private func open(_ area: Area) {
        cleanUp.open(area)
    }
}
