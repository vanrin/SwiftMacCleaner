//
//  DoneView.swift
//  Mac Disk Cleaner
//

import AppKit
import SwiftUI

/// Shown while the clean-up runs.
struct CleaningView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 14) {
            Text("Cleaning")
                .font(.title2.bold())
            ProgressView(value: model.cleanProgress.fraction)
                .frame(width: 320)
            Text(model.cleanProgress.status)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Cleaning")
        .navigationSubtitle(model.disk.name)
    }
}

/// The result: what the disk gained, a receipt, and what is still left to decide.
struct DoneView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            if let outcome = model.outcome {
                VStack(alignment: .leading, spacing: 28) {
                    result(outcome)
                    receipt(outcome)
                    followUps(outcome)
                }
                .pageLayout()
            }
        }
        .navigationTitle("Overview")
        .navigationSubtitle("\(model.disk.name), \(ByteFormat.string(model.disk.capacity))")
    }

    private func result(_ outcome: CleanOutcome) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HeroFigure(
                caption: "Reclaimed",
                bytes: outcome.reclaimed,
                footnote: "Free space went from \(ByteFormat.string(outcome.freeBefore)) to \(ByteFormat.string(outcome.freeAfter))"
            )
            DiskBar(
                segments: [
                    .init(id: "keep", label: "Keeping", bytes: max(0, model.disk.used - model.foundSize), color: DiskBar.keepColor),
                    .init(id: "found", label: "Still removable", bytes: model.foundSize, color: DiskBar.foundColor),
                    .init(id: "free", label: "Free now", bytes: model.disk.free, color: .clear, isRemainder: true),
                ],
                total: model.disk.capacity
            )
        }
    }

    private func receipt(_ outcome: CleanOutcome) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("What was removed")
                    .font(.headline)
                Spacer()
                if let log = outcome.logURL {
                    Button("Open Log") { NSWorkspace.shared.open(log) }
                }
            }
            VStack(spacing: 0) {
                ForEach(outcome.steps) { step in
                    Divider()
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: step.succeeded ? "checkmark" : "exclamationmark.triangle")
                            .foregroundStyle(step.succeeded ? AnyShapeStyle(.tint) : AnyShapeStyle(.orange))
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(step.title)
                                .fontWeight(.semibold)
                            Text(detail(for: step))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 12)
                        SizeLabel(bytes: step.size)
                    }
                    .padding(.vertical, 9)
                }
            }
        }
    }

    private func detail(for step: StepOutcome) -> String {
        if let reason = step.skippedReason { return reason }
        if let first = step.failures.first {
            let more = step.failures.count > 1 ? " (and \(step.failures.count - 1) more in the log)" : ""
            return first + more
        }
        switch step.method {
        case .delete: return "Deleted. It is rebuilt or downloaded again when needed."
        case .trash: return "Moved to the Trash."
        case .command: return "Removed by the tool that owns it."
        }
    }

    @ViewBuilder
    private func followUps(_ outcome: CleanOutcome) -> some View {
        let estimate = outcome.steps.filter { $0.succeeded && $0.method != .trash }.reduce(Int64(0)) { $0 + $1.size }
        VStack(alignment: .leading, spacing: 16) {
            if outcome.trashedSize > 0 {
                followUp(
                    title: "\(ByteFormat.string(outcome.trashedSize)) is waiting in the Trash",
                    text: "That space comes back when you empty the Trash.",
                    action: "Show Trash"
                ) { model.openTrash() }
            }
            if outcome.reclaimed < estimate / 2, estimate > 500_000_000 {
                followUp(
                    title: "Less came back than was removed",
                    text: "Files shared with a local snapshot or another copy only free their space once the last reference is gone. macOS usually catches up within a day.",
                    action: nil
                ) {}
            }
            if model.foundSize > 0 {
                followUp(
                    title: "\(ByteFormat.string(model.foundSize)) more needs your call",
                    text: "These were not selected, or could not be removed this time.",
                    action: "Review Them"
                ) { model.showResults() }
            }
        }
    }

    private func followUp(title: String, text: String, action: String?, perform: @escaping () -> Void) -> some View {
        Card {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontWeight(.semibold)
                    Text(text)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                if let action {
                    Button(action, action: perform)
                }
            }
            .padding(14)
        }
    }
}
