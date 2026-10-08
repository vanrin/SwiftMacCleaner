//
//  LeftoversPane.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Leftovers: installers that are no longer needed, and files of apps that are already gone.
/// These are the clean-up scan's own findings, shown here beside the apps they relate to.
struct LeftoversPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let apps = model.apps
        VStack(alignment: .leading, spacing: Design.Spacing.large) {
            AppsPaneHeading(title: "Leftovers", detail: AppsModel.Section.leftovers.detail) {
                if !apps.selectedLeftovers.isEmpty {
                    Button("Select None", action: apps.selectNone)
                        .buttonStyle(.pill)
                }
            }
            if apps.leftovers.isEmpty, apps.unreadable.isEmpty {
                ContentUnavailableView {
                    Label("Nothing left behind", systemImage: "puzzlepiece.extension")
                } description: {
                    Text("No installers in Downloads, and no sizeable files from apps that are no longer installed.")
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Design.Spacing.large) {
                        ForEach(apps.leftovers) { finding in
                            LeftoverCard(finding: finding)
                        }
                        if !apps.unreadable.isEmpty {
                            Notice(
                                symbol: "lock.fill",
                                title: "\(apps.unreadable.joined(separator: " and ")) could not be read",
                                text: "macOS keeps it private. Grant Full Disk Access in Privacy & Security, then scan again."
                            ) {
                                Button("Open Privacy Settings", action: model.openFullDiskAccessSettings)
                                    .buttonStyle(.pill)
                            }
                        }
                    }
                }
            }
        }
    }
}
