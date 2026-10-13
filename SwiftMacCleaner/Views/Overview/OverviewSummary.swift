//
//  OverviewSummary.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What every part found: all of it in the headline, one tile each with a box to tick, and the round
/// button that runs the ticked ones. Each clean-up cleans what is ticked in it, and Performance runs
/// its recommended tasks.
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
                    if model.hasFindings {
                        HStack(spacing: Design.Spacing.medium) {
                            if model.runSize > 0 {
                                FreeSpaceForecast(now: model.disk.free, after: model.disk.free + model.runSize)
                            }
                            SelectionMenu(preset: model.preset, select: model.select)
                        }
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
        if model.foundSize > 0 {
            return "\(ByteFormat.string(model.foundSize)) found on \(model.disk.name)"
        }
        if model.overviewParts.contains(where: model.hasWork) {
            return runs.isEmpty ? "Nothing is ticked to run" : "Everything is ready to run"
        }
        return "Nothing needs doing right now"
    }

    private func detail(_ runs: [SidebarItem]) -> String {
        guard model.foundSize > 0 || model.overviewParts.contains(where: model.hasWork) else {
            return "The scan found nothing worth removing and no task worth running. Each part still shows what it looked at."
        }
        let runsTasks = runs.contains(.performance)
        var text: String
        if model.runSize > 0 || model.runHasUnknownSize {
            let who = model.preset == .smart ? "Smart selection has ticked" : "You have ticked"
            let waiting = model.runWaitingSize
            text = "\(who) \(ByteFormat.string(model.runSize + waiting)) of it. Run cleans that part\(runsTasks ? " and runs the maintenance tasks" : ""). Open a part to tick more or less."
            if waiting > 0 {
                let apps = model.runBlockingApps.map(\.app.name)
                let names = apps.isEmpty ? "something that is running" : ListFormat.string(apps)
                text += " \(ByteFormat.string(waiting)) waits for \(names) to quit, which the confirmation offers."
            }
        } else if runsTasks {
            text = "Nothing is ticked to clean, so Run only runs the maintenance tasks. Open a part to choose what goes."
        } else {
            text = "Nothing is ticked. Open a part to choose what goes, or pick Smart or Everything under Select."
        }
        let plan = model.runPlan
        switch plan.passwordPromptCount {
        case 0: break
        case 1: text += " macOS asks for your password once."
        default: text += " macOS asks for your password \(plan.passwordPromptTimes), once for each part that needs root."
        }
        return text
    }
}
