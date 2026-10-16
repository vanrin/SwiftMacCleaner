//
//  RecentCard.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The newest runs, and the way to all of them in History.
struct RecentCard: View {
    @Environment(AppModel.self) private var model
    /// How many runs fit.
    var rows = 4

    var body: some View {
        let activity = model.activity
        let recent = activity.recent(rows)
        ActivityCard(title: "Recent") {
            if !recent.isEmpty {
                Button(action: activity.showHistory) {
                    HStack(spacing: Design.Spacing.tight) {
                        Text("Show All")
                        Image(systemName: "chevron.right")
                            .imageScale(.small)
                    }
                }
                .buttonStyle(.compactPill)
            }
        } content: {
            if recent.isEmpty {
                VStack(spacing: Design.Spacing.medium) {
                    ModuleIcon(symbol: .moduleActivity, theme: .graphite, size: 56, depth: Design.Depth.tile)
                        .opacity(0.55)
                    Text("Each clean will be listed here with what it removed and its log. What went to the Trash can be put back from here.")
                        .font(.callout)
                        .foregroundStyle(.quiet)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 260)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, record in
                        if index > 0 {
                            Divider()
                        }
                        row(record)
                    }
                }
            }
        }
    }

    private func row(_ record: ActivityRecord) -> some View {
        HStack(spacing: Design.Spacing.medium) {
            ModuleIcon(symbol: record.part.item.icon, theme: record.part.item.theme, size: 28, depth: Design.Depth.selected)
            VStack(alignment: .leading, spacing: 1) {
                Text(record.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text("\(record.date.formatted(.dateTime.day().month(.abbreviated))), \(record.date.formatted(date: .omitted, time: .shortened)) · \(record.part.title)")
                    .font(.caption)
                    .foregroundStyle(.quiet)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(record.figure)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
        }
        .frame(height: Design.Size.activityRow)
        .accessibilityElement(children: .combine)
    }
}
