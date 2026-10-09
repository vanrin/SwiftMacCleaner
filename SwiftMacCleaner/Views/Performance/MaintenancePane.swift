//
//  MaintenancePane.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The maintenance tasks, every one of them, with the recommended ones ticked.
struct MaintenancePane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let performance = model.performance
        VStack(alignment: .leading, spacing: Design.Spacing.large) {
            PaneHeading(title: PerformanceModel.Section.maintenance.title, detail: PerformanceModel.Section.maintenance.detail) {
                Spacer(minLength: 0)
                Menu("Select") {
                    Button("Recommended", action: performance.selectRecommended)
                    Button("All", action: performance.selectAll)
                    Button("None", action: performance.selectNone)
                }
                .fixedSize()
            }
            ScrollView {
                GlassPanel {
                    LazyVStack(spacing: 0) {
                        ForEach(performance.checks) { check in
                            MaintenanceRow(check: check, showsDivider: check.id != performance.checks.first?.id)
                        }
                    }
                }
            }
        }
    }
}
