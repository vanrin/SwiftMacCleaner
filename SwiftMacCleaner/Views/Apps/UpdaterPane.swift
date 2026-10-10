//
//  UpdaterPane.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The updater: apps that have a newer version, with what changed and a way to where each is installed.
/// An app Homebrew installed is updated from here, by Homebrew. For the rest this app installs nothing
/// itself: the App Store and each app's own updater check what they download.
struct UpdaterPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let apps = model.apps
        let hasStoreUpdates = apps.updates.contains { $0.feed == .appStore }
        VStack(alignment: .leading, spacing: Design.Spacing.large) {
            PaneHeading(title: "App Updates", detail: AppsModel.Section.updater.detail) {
                if hasStoreUpdates {
                    Button("Open App Store Updates", action: apps.openAppStoreUpdates)
                        .buttonStyle(.pill)
                }
                let installable = apps.installableUpdates.filter { !apps.installing.contains($0.id) }
                if installable.count > 1 {
                    Button("Update \(installable.count) with Homebrew", action: installAll)
                        .buttonStyle(.pill)
                        .help("Homebrew downloads and installs them one after another")
                }
            }
            if apps.updates.isEmpty {
                ContentUnavailableView {
                    Label(apps.checkedUpdates ? "Your apps are up to date" : "Updates were not checked", systemImage: "arrow.up.circle")
                } description: {
                    Text(apps.checkedUpdates
                         ? "No newer version was found. Only apps from the App Store or Homebrew, and apps that say where they publish updates, can be checked."
                         : "Looking for app updates is switched off in Settings, under General.")
                }
            } else {
                ScrollView {
                    GlassPanel {
                        ForEach(apps.updates) { update in
                            if let app = apps.app(withID: update.id) {
                                UpdateRow(app: app, update: update, showsDivider: update.id != apps.updates.first?.id)
                            }
                        }
                    }
                    .padding(.bottom, Design.Spacing.pageVertical)
                }
            }
        }
    }

    private func installAll() {
        model.apps.install(model.apps.installableUpdates)
    }
}
