//
//  AppsManager.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// The manager: a column that chooses between uninstalling, updating and leftovers, and beside it the
/// list for the chosen part. What is ticked is acted on with the round button.
struct AppsManager: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let apps = model.apps
        HStack(alignment: .top, spacing: Design.Spacing.xLarge) {
            AppsColumn()
                .frame(width: Design.Size.filterColumn)
            Group {
                switch apps.section {
                case .uninstaller:
                    UninstallerPane()
                case .updater:
                    UpdaterPane()
                case .leftovers:
                    LeftoversPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, Design.Spacing.pageHorizontal)
        .padding(.top, Design.Spacing.pageVertical)
        .frame(maxWidth: 1100)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .orbAction {
            // Updates are installed by the App Store or the app itself, so that part has nothing to confirm.
            if apps.section != .updater {
                AppsRemoveButton()
            }
        }
    }
}
