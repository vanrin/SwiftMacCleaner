//
//  AppsSummary.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What the Applications scan found: how many apps there are, and a tile for each thing worth a look.
struct AppsSummary: View {
    @Environment(AppModel.self) private var model

    private let columns = [GridItem(.flexible(), spacing: Design.Spacing.large), GridItem(.flexible())]

    var body: some View {
        let apps = model.apps
        let unused = apps.unusedApps
        ScrollView {
            VStack(spacing: Design.Spacing.section) {
                VStack(spacing: Design.Spacing.large) {
                    Text("\(apps.apps.count.formatted()) \(apps.apps.count == 1 ? "app" : "apps") on this Mac")
                        .font(Design.Typeface.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text("Together with the files they keep in your Library, they take up \(ByteFormat.string(apps.apps.reduce(0) { $0 + $1.size })).")
                        .font(Design.Typeface.tileBody)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Manage My Applications", action: manageAll)
                        .buttonStyle(.primaryPill)
                        .disabled(apps.apps.isEmpty)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Design.Spacing.medium)

                LazyVGrid(columns: columns, spacing: Design.Spacing.large) {
                    SummaryTile(
                        title: updatesTitle(apps), detail: updatesDetail(apps), glyph: .glyphUpdater,
                        icons: apps.updates.prefix(3).compactMap { apps.app(withID: $0.id)?.url },
                        isActionable: !apps.updates.isEmpty, action: reviewUpdates
                    )
                    SummaryTile(
                        title: unused.isEmpty ? "No unused apps" : "\(unused.count) unused \(unused.count == 1 ? "app" : "apps")",
                        detail: unused.isEmpty
                            ? "Every app here was opened in the last 6 months."
                            : "Not opened for 6 months or more. Together they take up \(ByteFormat.string(unused.reduce(0) { $0 + $1.size })).",
                        glyph: .glyphUnused, icons: unused.prefix(3).map(\.url),
                        isActionable: !unused.isEmpty, action: reviewUnused
                    )
                    SummaryTile(
                        title: apps.leftoverFileSize == 0 ? "No app leftovers" : "\(ByteFormat.string(apps.leftoverFileSize)) of app leftovers",
                        detail: apps.leftoverFileSize == 0
                            ? "Nothing sizeable was left behind by apps that are gone."
                            : "Files in your Library that belong to apps that are no longer installed.",
                        glyph: .glyphLeftovers, isActionable: apps.leftoverFileSize > 0, action: reviewLeftovers
                    )
                    SummaryTile(
                        title: apps.installerSize == 0 ? "No installers" : "\(ByteFormat.string(apps.installerSize)) of installers",
                        detail: installersDetail(apps), glyph: .glyphInstallers,
                        isActionable: apps.installerSize > 0, action: reviewLeftovers
                    )
                }
            }
            .pageLayout()
        }
    }

    private func updatesTitle(_ apps: AppsModel) -> String {
        if !apps.checkedUpdates { return "Updates were not checked" }
        let count = apps.updates.count
        return count == 0 ? "Apps are up to date" : "\(count) app \(count == 1 ? "update" : "updates") available"
    }

    private func updatesDetail(_ apps: AppsModel) -> String {
        if !apps.checkedUpdates { return "Looking for app updates is switched off in Settings." }
        return apps.updates.isEmpty
            ? "No newer version was found for the apps that say where they publish one."
            : "Newer versions with fixes and features. Each is installed by the App Store or by the app itself."
    }

    private func installersDetail(_ apps: AppsModel) -> String {
        if apps.unreadable.contains("Downloads") { return "macOS did not let the app read Downloads. Grant Full Disk Access to include it." }
        return apps.installerSize == 0
            ? "No disk images or installer packages in Downloads."
            : "Disk images and installer packages in Downloads, rarely needed once the app is installed."
    }

    private func manageAll() {
        model.apps.manage(.uninstaller)
    }

    private func reviewUpdates() {
        model.apps.manage(.updater)
    }

    private func reviewUnused() {
        model.apps.manage(.uninstaller, filter: .unused)
    }

    private func reviewLeftovers() {
        model.apps.manage(.leftovers)
    }
}
