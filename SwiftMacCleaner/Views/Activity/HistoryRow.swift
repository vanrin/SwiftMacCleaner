//
//  HistoryRow.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One run in History: when, which part, what it did and what it came to. Opened, it lists each line
/// of what it did, and names its log.
struct HistoryRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let record: ActivityRecord

    var body: some View {
        let activity = model.activity
        let isOpen = activity.expanded == record.id
        let inTrash = record.waitingInTrash(pending: model.putBackSet)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Design.Spacing.large - 2) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(record.date.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.callout.weight(.semibold))
                    Text(record.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.quiet)
                        .monospacedDigit()
                }
                .frame(width: Design.Size.historyDate, alignment: .leading)
                ModuleIcon(symbol: record.part.item.icon, theme: record.part.item.theme, size: 30, depth: Design.Depth.selected)
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.title)
                        .font(Design.Typeface.rowTitle)
                        .lineLimit(1)
                    Text("\(record.part.title) · \(record.detail)")
                        .font(.callout)
                        .foregroundStyle(.quiet)
                        .lineLimit(1)
                }
                Spacer(minLength: Design.Spacing.medium)
                if !inTrash.isEmpty {
                    Text("\(ByteFormat.string(inTrash.reduce(0) { $0 + $1.size })) in the Trash")
                        .font(.callout)
                        .foregroundStyle(.quiet)
                        .lineLimit(1)
                        .fixedSize()
                    Button("Put Back") { model.putBack(record) }
                        .buttonStyle(PillButtonStyle(kind: .primary, isCompact: true))
                        .help("Return what this run moved to the Trash to where it was")
                }
                Text(record.figure)
                    .font(Design.Typeface.rowTitle)
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(minWidth: Design.Size.sizeColumn - 8, alignment: .trailing)
                Button {
                    activity.toggle(record)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.quiet)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                        .frame(width: 28, height: 28)
                        .background(isOpen ? Design.Surface.quietButton : .clear, in: .circle)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isOpen ? "Hide what this run did" : "Show what this run did")
            }
            .frame(minHeight: 62)
            .contentShape(.rect)
            .onTapGesture { activity.toggle(record) }
            if isOpen {
                details
                    .padding(.leading, Design.Size.historyDate + 30 + 2 * (Design.Spacing.large - 2))
                    .padding(.bottom, Design.Spacing.medium + 2)
                    .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.2), value: isOpen)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(record.lines.enumerated()), id: \.offset) { _, line in
                HStack(spacing: Design.Spacing.small + 2) {
                    Circle()
                        .fill(color(of: line.fate))
                        .frame(width: 7, height: 7)
                    Text(line.what)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if record.part == .overview, line.part != .overview {
                        Text(line.part.title)
                            .foregroundStyle(.quiet)
                            .lineLimit(1)
                    }
                    Spacer(minLength: Design.Spacing.medium)
                    Text(line.fateText)
                        .foregroundStyle(.quiet)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(line.size > 0 ? ByteFormat.string(line.size) : "")
                        .bold()
                        .monospacedDigit()
                        .foregroundStyle(line.fate.removes ? AnyShapeStyle(.primary) : AnyShapeStyle(.quiet))
                        .frame(width: Design.Size.sizeColumn - 12, alignment: .trailing)
                }
                .font(.callout)
                .frame(minHeight: 26)
                .accessibilityElement(children: .combine)
            }
            let back = record.trashed.filter(\.isPutBack).reduce(Int64(0)) { $0 + $1.item.size }
            if back > 0 {
                Text("\(ByteFormat.string(back)) of it was put back since, so it no longer counts as cleaned.")
                    .font(.callout)
                    .foregroundStyle(.quiet)
                    .padding(.top, Design.Spacing.small)
            }
            if let note = record.note {
                Text(note)
                    .font(.callout)
                    .foregroundStyle(.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Design.Spacing.small)
            }
            if let log = model.activity.logURL(of: record) {
                Divider()
                    .padding(.top, Design.Spacing.small + 2)
                HStack(spacing: Design.Spacing.medium) {
                    Text(log.lastPathComponent)
                        .font(Design.Typeface.code)
                        .foregroundStyle(.quiet)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                    Button("Show Log") { model.activity.open(log) }
                        .buttonStyle(.compactPill)
                }
                .padding(.top, Design.Spacing.small + 2)
            }
        }
        .padding(.horizontal, Design.Spacing.large)
        .padding(.vertical, Design.Spacing.medium)
        .background(Design.Surface.well, in: .rect(cornerRadius: Design.Radius.control + 2))
    }

    /// The dot before a line: steel for what went for good, amber for the Trash, green for what ran,
    /// grey for what stayed.
    private func color(of fate: ActivityRecord.Line.Fate) -> Color {
        switch fate {
        case .deleted, .trashEmptied, .deletedAsRoot, .removed: theme.accent
        case .trashed: Theme.amber.lens
        case .ran, .updated: Theme.green.lens
        case .waited, .failed: Design.Ink.tertiary
        }
    }
}
