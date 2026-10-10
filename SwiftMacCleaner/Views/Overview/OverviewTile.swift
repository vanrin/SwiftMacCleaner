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
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
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

    /// The large figure and the line under it: what Run would do here, in the part's own terms.
    private var figure: (value: String, caption: String) {
        if model.isScanning(part) { return ("Scanning", "still looking") }
        guard model.hasResults(part) else { return ("Not scanned", "open it to scan on its own") }
        switch part {
        case .group(let group):
            let cleanUp = model.cleanUp(group)
            let found = cleanUp.foundSize
            if cleanUp.phase == .done { return ("Cleaned", found > 0 ? "\(ByteFormat.string(found)) more needs your call" : "nothing left to decide") }
            if found == 0 { return ("Nothing", "to clean") }
            let selected = cleanUp.selectedSize
            if selected == 0 && !cleanUp.selectionHasUnknownSize {
                return ("Nothing ticked", "\(ByteFormat.string(found)) found needs your call")
            }
            let more = found - selected
            return (ByteFormat.string(selected), more > 0 ? "to clean · \(ByteFormat.string(more)) more needs your call" : "to clean")
        case .performance:
            let performance = model.performance
            let count = performance.recommended.count
            if performance.phase == .done { return ("Ran", "the tasks that were due") }
            return count == 0 ? ("Nothing", "to run today") : ("\(count) \(count == 1 ? "task" : "tasks")", "to run")
        case .apps:
            let apps = model.apps
            if !apps.updates.isEmpty {
                let count = apps.updates.count
                return ("\(count) \(count == 1 ? "update" : "updates")", "to install from the store or the app")
            }
            let leftovers = apps.leftoverFileSize + apps.installerSize
            if leftovers > 0 { return (ByteFormat.string(leftovers), "of leftovers and installers to review") }
            let unused = apps.unusedApps.count
            return unused > 0 ? ("\(unused) unused \(unused == 1 ? "app" : "apps")", "to review") : ("Up to date", "nothing to remove")
        case .overview, .space, .duplicates:
            return ("", "")
        }
    }

    private func open() {
        model.select(part)
    }
}
