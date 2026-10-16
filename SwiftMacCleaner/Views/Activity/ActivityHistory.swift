//
//  ActivityHistory.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Every run the app has made on this Mac, newest first and a month at a time. Each opens into what
/// it did, with its log; what one moved to the Trash can be put back from its row while it is there.
struct ActivityHistory: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var activity = model.activity
        let months = activity.months()
        VStack(alignment: .leading, spacing: Design.Spacing.large + 2) {
            HStack(alignment: .bottom, spacing: Design.Spacing.large) {
                VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
                    Text("History")
                        .font(Design.Typeface.heroTitle)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .font(Design.Typeface.tileBody)
                        .foregroundStyle(.quiet)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Picker("Show", selection: $activity.filter) {
                    ForEach(ActivityModel.Filter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            GlassPanel {
                if months.isEmpty {
                    Text(activity.isEmpty ? "Nothing has been done yet. Every clean, uninstall, update and task will be listed here."
                                          : "Nothing of this kind has been done yet.")
                        .font(Design.Typeface.tileBody)
                        .foregroundStyle(.quiet)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(Design.Spacing.xLarge)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(months) { month in
                                Section {
                                    ForEach(month.records) { record in
                                        Divider()
                                        HistoryRow(record: record)
                                    }
                                } header: {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(month.start.formatted(.dateTime.month(.wide).year()))
                                            .font(Design.Typeface.rowTitle)
                                            .accessibilityAddTraits(.isHeader)
                                        Spacer(minLength: 0)
                                        Text(month.cleaned > 0 ? "\(ByteFormat.string(month.cleaned)) cleaned" : "Nothing cleaned")
                                            .font(.callout)
                                            .foregroundStyle(.quiet)
                                    }
                                    .padding(.top, Design.Spacing.large)
                                    .padding(.bottom, Design.Spacing.small)
                                }
                            }
                        }
                        .padding(.horizontal, Design.Spacing.large + Design.Spacing.tight + 2)
                        .padding(.bottom, Design.Spacing.large)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            HStack(spacing: Design.Spacing.medium) {
                Text("Each run also leaves its full log in ~/Library/Logs/\(CleanLog.folderName).")
                Spacer(minLength: 0)
                Text("Put Back works while the items are still in the Trash.")
            }
            .font(.callout)
            .foregroundStyle(.quiet)
            .lineLimit(1)
        }
        .padding(.horizontal, Design.Spacing.pageHorizontal)
        .padding(.top, Design.Spacing.small)
        .padding(.bottom, Design.Spacing.large)
    }

    private var subtitle: String {
        guard let since = model.activity.since else { return "Everything the app does on this Mac will be listed here." }
        return "Everything the app has done on this Mac since \(since.formatted(.dateTime.day().month(.wide).year()))."
    }
}
