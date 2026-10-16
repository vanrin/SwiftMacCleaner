//
//  CleanedCard.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Everything the app has removed from this Mac, split by the part that removed it. Pointing at a
/// part, in the bar or its legend, sets it apart from the rest.
struct CleanedCard: View {
    @Environment(AppModel.self) private var model
    @State private var pointed: ActivityRecord.Part?

    static let info = "Everything the app has removed from this Mac, deleted or moved to the Trash, at the size the scan measured. What you put back is taken off again. It is read from the app's own record of each run, kept on this Mac; nothing is estimated."

    var body: some View {
        let activity = model.activity
        let parts = activity.cleanedByPart
        ActivityCard(title: "Cleaned", info: Self.info) {
            if parts.isEmpty {
                ActivityFigure(value: "Nothing yet", isEmpty: true)
                Capsule()
                    .fill(Design.Surface.track)
                    .frame(height: Design.Size.partBar)
                    .padding(.top, Design.Spacing.medium)
                Text("What you clean adds up here, part by part, from the first clean on. Only what the app really removed counts.")
                    .font(.callout)
                    .foregroundStyle(.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Design.Spacing.small)
                Spacer(minLength: 0)
                Button("Go to Overview", action: openOverview)
                    .buttonStyle(.compactPill)
            } else {
                VStack(alignment: .leading, spacing: Design.Spacing.tight) {
                    ActivityFigure(value: ByteFormat.string(activity.cleaned))
                    let month = activity.cleanedThisMonth()
                    if month > 0 {
                        MonthGain(text: "\(ByteFormat.string(month)) in \(Date().formatted(.dateTime.month(.wide)))")
                    }
                }
                ProportionalRow(total: Double(parts.reduce(0) { $0 + $1.size }), spacing: 2) {
                    ForEach(parts, id: \.part) { entry in
                        Rectangle()
                            .fill(entry.part.item.theme.lens)
                            .opacity(opacity(of: entry.part))
                            .layoutValue(key: ProportionKey.self, value: Double(entry.size))
                            .onHover { inside in point(inside ? entry.part : nil) }
                            .help("\(entry.part.title): \(ByteFormat.string(entry.size))")
                    }
                }
                .frame(height: Design.Size.partBar)
                .clipShape(.capsule)
                .padding(.top, Design.Spacing.medium)
                .accessibilityHidden(true)
                VStack(spacing: Design.Spacing.tight + 1) {
                    ForEach(parts.prefix(5), id: \.part) { entry in
                        HStack(spacing: Design.Spacing.small + 1) {
                            Circle()
                                .fill(entry.part.item.theme.lens)
                                .frame(width: 8, height: 8)
                            Text(entry.part.title)
                                .lineLimit(1)
                            Spacer(minLength: Design.Spacing.small)
                            Text(ByteFormat.string(entry.size))
                                .bold()
                                .monospacedDigit()
                        }
                        .font(.callout)
                        .opacity(opacity(of: entry.part))
                        .contentShape(.rect)
                        .onHover { inside in point(inside ? entry.part : nil) }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.top, Design.Spacing.small)
                Spacer(minLength: 0)
                if let pending = model.putBackPending {
                    Text("\(ByteFormat.string(pending.items.reduce(0) { $0 + $1.size })) of it is still in the Trash.")
                        .font(.callout)
                        .foregroundStyle(.quiet)
                        .lineLimit(1)
                        .help("Put Back in the title bar returns it to where it was, until the Trash is emptied.")
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: pointed)
    }

    private func opacity(of part: ActivityRecord.Part) -> Double {
        pointed == nil || pointed == part ? 1 : 0.35
    }

    private func point(_ part: ActivityRecord.Part?) {
        pointed = part
    }

    private func openOverview() {
        model.select(.overview)
    }
}
