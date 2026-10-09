//
//  PerformanceColumn.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The column beside the manager's list: its three parts, each with how much is in it.
struct PerformanceColumn: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let performance = model.performance
        VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
            ForEach(PerformanceModel.Section.allCases) { section in
                ManagerColumnRow(title: section.title, value: value(for: section, in: performance),
                                 isSelected: performance.section == section, isProminent: true) {
                    performance.section = section
                }
            }
        }
    }

    /// What stands at the end of a part's row: how many tasks are recommended, or how many items there are.
    private func value(for section: PerformanceModel.Section, in performance: PerformanceModel) -> String {
        switch section {
        case .maintenance: performance.recommended.count.formatted()
        case .loginItems: performance.loginItems.count.formatted()
        case .backgroundItems: performance.backgroundItems.count.formatted()
        }
    }
}
