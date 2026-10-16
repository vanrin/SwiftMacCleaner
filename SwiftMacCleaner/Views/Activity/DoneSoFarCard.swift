//
//  DoneSoFarCard.swift
//  SwiftMacCleaner
//

import SwiftUI

/// How often the app has cleaned, week by week, and everything else it has done besides.
struct DoneSoFarCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    static let info = "Each clean, uninstall, update and maintenance task the app carried out counts once, on the day it ran. A run from the Overview counts as one clean, however many parts it covered."

    var body: some View {
        let activity = model.activity
        let weeks = activity.weeklyCleans()
        ActivityCard(title: "Done so far", info: activity.isEmpty ? nil : Self.info) {
            HStack(alignment: .bottom, spacing: Design.Spacing.medium) {
                VStack(alignment: .leading, spacing: Design.Spacing.tight) {
                    if activity.isEmpty {
                        ActivityFigure(value: "Nothing yet", isEmpty: true)
                    } else {
                        ActivityFigure(value: activity.cleans.formatted(), unit: activity.cleans == 1 ? "clean" : "cleans")
                        let month = activity.cleansThisMonth()
                        if month > 0 {
                            MonthGain(text: "\(month) in \(Date().formatted(.dateTime.month(.wide)))")
                        }
                    }
                }
                Spacer(minLength: 0)
                weekChart(weeks)
            }
            Divider()
                .padding(.vertical, Design.Spacing.small)
            if activity.isEmpty {
                Text("Each clean, uninstall, update and maintenance task is counted here on the day it runs, with a bar for each week.")
                    .font(.callout)
                    .foregroundStyle(.quiet)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Besides cleaning")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.quiet)
                VStack(spacing: Design.Spacing.tight + 1) {
                    ForEach(activity.tallies) { tally in
                        HStack(spacing: Design.Spacing.medium) {
                            Text(tally.name)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 0)
                            Text(tally.count.formatted())
                                .bold()
                                .monospacedDigit()
                        }
                        .font(.callout)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    /// A bar for each of the last weeks, the oldest first, with this week in ink.
    private func weekChart(_ weeks: [Int]) -> some View {
        let tallest = max(weeks.max() ?? 0, 1)
        return VStack(alignment: .trailing, spacing: Design.Spacing.tight + 2) {
            HStack(alignment: .bottom, spacing: Design.Spacing.tight) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { index, count in
                    let isThisWeek = index == weeks.count - 1
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isThisWeek ? AnyShapeStyle(Design.Ink.primary) : count == 0 ? AnyShapeStyle(Design.Surface.track)
                              : AnyShapeStyle(theme.accent.opacity(0.55)))
                        .frame(width: Design.Size.weekBar,
                               height: 4 + (Design.Size.weekChart - 4) * Double(count) / Double(tallest))
                        .help(isThisWeek ? "This week: \(cleans(count))" : "\(weeks.count - 1 - index) \(weeks.count - 1 - index == 1 ? "week" : "weeks") ago: \(cleans(count))")
                }
            }
            .frame(height: Design.Size.weekChart, alignment: .bottom)
            Text("a week, last \(weeks.count)")
                .font(.caption)
                .foregroundStyle(.quiet)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cleans each week for the last \(weeks.count) weeks")
        .accessibilityValue(weeks.map(String.init).joined(separator: ", "))
    }

    private func cleans(_ count: Int) -> String {
        count == 1 ? "1 clean" : "\(count) cleans"
    }
}
