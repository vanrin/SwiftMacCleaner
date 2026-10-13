//
//  OverviewTile.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One part of the app on the overview: a box to tick when Run should act on it, the figure that
/// matters, and a way into the part itself.
struct OverviewTile: View {
    @Environment(AppModel.self) private var model
    let part: SidebarItem

    var body: some View {
        let figure = figure
        let canRun = model.hasWork(part)
        GlassPanel(cornerRadius: Design.Radius.tile) {
            VStack(alignment: .leading, spacing: Design.Spacing.small) {
                HStack(alignment: .top, spacing: Design.Spacing.medium) {
                    if canRun {
                        Toggle(isOn: model.inclusion(of: part)) {
                            Text(part.title)
                                .font(Design.Typeface.rowTitle)
                                .lineLimit(1)
                        }
                        .toggleStyle(.check)
                    } else {
                        Text(part.title)
                            .font(Design.Typeface.rowTitle)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    FeatureIcon(Image(part.glyph), theme: part.theme, size: Design.Size.tileIcon)
                }
                Spacer(minLength: 0)
                // The figure and its line sit at the bottom left, the way in at the bottom right.
                HStack(alignment: .bottom, spacing: Design.Spacing.medium) {
                    VStack(alignment: .leading, spacing: Design.Spacing.tight) {
                        Text(figure.value)
                            .font(Design.Typeface.tileTitle)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .contentTransition(.numericText())
                        Text(figure.caption)
                            .font(Design.Typeface.tileBody)
                            .foregroundStyle(.quiet)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        if let selection = figure.selection {
                            Text(selection)
                                .font(Design.Typeface.tileBody)
                                .bold(figure.isSelected)
                                .foregroundStyle(figure.isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.quiet))
                                .lineLimit(1)
                                .contentTransition(.numericText())
                        }
                    }
                    Spacer(minLength: 0)
                    Button("Review", action: open)
                        .buttonStyle(.pill)
                        .fixedSize()
                        .disabled(!model.hasResults(part))
                        .accessibilityLabel("Review \(part.title)")
                }
            }
            .padding(Design.Spacing.large)
            .frame(height: Design.Size.tileHeight, alignment: .topLeading)
        }
        .accessibilityElement(children: .contain)
    }

    /// What a tile says under its name: the figure that matters, the line under it, and for a clean-up
    /// how much of what was found is ticked.
    private struct Figure {
        var value: String
        var caption: String
        var selection: String? = nil
        var isSelected = false

        init(_ value: String, _ caption: String, selection: String? = nil, isSelected: Bool = false) {
            self.value = value
            self.caption = caption
            self.selection = selection
            self.isSelected = isSelected
        }
    }

    /// The large figure and the lines under it. A clean-up shows everything it found, and then what
    /// Run would take of it; the other parts say what Run would do in their own terms.
    private var figure: Figure {
        if model.isScanning(part) { return Figure("Scanning", "still looking") }
        guard model.hasResults(part) else { return Figure("Not scanned", "open it to scan on its own") }
        switch part {
        case .group(let group):
            let cleanUp = model.cleanUp(group)
            let found = cleanUp.foundSize
            if cleanUp.phase == .done { return Figure("Cleaned", found > 0 ? "\(ByteFormat.string(found)) more found, not selected" : "nothing left") }
            if found == 0 { return Figure("Nothing", "to clean") }
            let selected = cleanUp.selectedSize
            let isSelected = selected > 0 || cleanUp.selectionHasUnknownSize
            return Figure(ByteFormat.string(found), group.holdsJunk ? "of junk found" : "found",
                          selection: isSelected ? "\(ByteFormat.string(selected)) selected" : "Nothing selected",
                          isSelected: isSelected)
        case .performance:
            let performance = model.performance
            let count = performance.recommended.count
            if performance.phase == .done { return Figure("Ran", "the tasks that were due") }
            return count == 0 ? Figure("Nothing", "to run today") : Figure("\(count) \(count == 1 ? "task" : "tasks")", "to run")
        case .protection:
            let protection = model.protection
            let count = protection.toLookAt.count
            let inPlace = protection.inPlace.count
            return count == 0
                ? Figure("In place", "\(inPlace) of \(protection.findings.count) defences are on")
                : Figure("\(count) \(count == 1 ? "setting" : "settings")", "worth a look in System Settings")
        case .apps:
            let apps = model.apps
            if !apps.updates.isEmpty {
                let count = apps.updates.count
                return Figure("\(count) \(count == 1 ? "update" : "updates")", "to install from the store or the app")
            }
            let leftovers = apps.leftoverFileSize + apps.installerSize
            if leftovers > 0 { return Figure(ByteFormat.string(leftovers), "of leftovers and installers to review") }
            let unused = apps.unusedApps.count
            return unused > 0 ? Figure("\(unused) unused \(unused == 1 ? "app" : "apps")", "to review") : Figure("Up to date", "nothing to remove")
        case .overview, .space, .duplicates:
            return Figure("", "")
        }
    }

    private func open() {
        model.select(part)
    }
}
