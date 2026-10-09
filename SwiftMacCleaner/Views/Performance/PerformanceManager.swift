//
//  PerformanceManager.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The manager: a column that chooses between the tasks, the login items and the background items, and
/// beside it the list for the chosen part. What is ticked is acted on with the round button.
struct PerformanceManager: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let performance = model.performance
        HStack(alignment: .top, spacing: Design.Spacing.xLarge) {
            PerformanceColumn()
                .frame(width: Design.Size.filterColumn)
            Group {
                switch performance.section {
                case .maintenance:
                    MaintenancePane()
                case .loginItems:
                    LoginItemsPane()
                case .backgroundItems:
                    BackgroundItemsPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, Design.Spacing.pageHorizontal)
        .padding(.top, Design.Spacing.pageVertical)
        .frame(maxWidth: 1100)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .orbAction {
            PerformanceRunButton()
        }
    }
}
