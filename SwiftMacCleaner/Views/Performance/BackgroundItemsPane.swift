//
//  BackgroundItemsPane.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The launch agents and daemons other makers installed, narrowed by the search, each with a tick box.
struct BackgroundItemsPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var performance = model.performance
        let shown = performance.visibleBackgroundItems
        VStack(alignment: .leading, spacing: Design.Spacing.large) {
            PaneHeading(title: PerformanceModel.Section.backgroundItems.title, detail: PerformanceModel.Section.backgroundItems.detail) {
                SearchField(text: $performance.search, prompt: "Search items")
                Spacer(minLength: 0)
                Menu("Select") {
                    Button("All Shown", action: performance.selectAll)
                    Button("None", action: performance.selectNone)
                }
                .fixedSize()
                .disabled(performance.backgroundItems.isEmpty)
            }
            if shown.isEmpty, performance.backgroundIssues.isEmpty {
                ContentUnavailableView {
                    Label(performance.backgroundItems.isEmpty ? "No background items" : "No item matches", systemImage: "gearshape.2")
                } description: {
                    Text(performance.backgroundItems.isEmpty
                         ? "No launch agents or daemons from other makers are installed."
                         : "No item has “\(performance.search)” in its name.")
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Design.Spacing.large) {
                        if !shown.isEmpty {
                            GlassPanel {
                                LazyVStack(spacing: 0) {
                                    ForEach(shown) { item in
                                        BackgroundItemRow(item: item, showsDivider: item.id != shown.first?.id)
                                    }
                                }
                            }
                        }
                        if !performance.backgroundIssues.isEmpty {
                            Notice(
                                symbol: "exclamationmark.triangle.fill", isWarning: true,
                                title: performance.backgroundIssues.count == 1 ? "One thing could not be read" : "\(performance.backgroundIssues.count) things could not be read",
                                text: performance.backgroundIssues.joined(separator: " ")
                            )
                        }
                    }
                }
            }
        }
    }
}
