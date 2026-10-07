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
                    followUps(outcome)
                    receipt(outcome)
                }
                .pageLayout()
            }
        }
        .navigationTitle("Overview")
        .navigationSubtitle("\(model.disk.name), \(ByteFormat.string(model.disk.capacity))")
    }

    private func result(_ outcome: CleanOutcome) -> some View {
        let seconds = Int(outcome.duration.rounded())
        let took = seconds >= 60 ? "\(seconds / 60) min \(seconds % 60) s" : "\(seconds) s"
        return VStack(alignment: .leading, spacing: 16) {
            HeroFigure(
                caption: "Reclaimed",
                bytes: outcome.reclaimed,
                footnote: "Free space went from \(ByteFormat.string(outcome.freeBefore)) to \(ByteFormat.string(outcome.freeAfter)), measured on the disk, in \(took)."
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
                Text("What happened, step by step")
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
                        icon(for: step)
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
                        SizeLabel(bytes: step.size, weight: step.skippedReason == nil ? .semibold : .regular)
                            .foregroundStyle(step.skippedReason == nil ? .primary : .secondary)
                    }
                    .padding(.vertical, 9)
                }
            }
        }
    }

    @ViewBuilder
    private func icon(for step: StepOutcome) -> some View {
        if step.skippedReason != nil {
            Image(systemName: "minus.circle").foregroundStyle(.secondary)
        } else if step.failures.isEmpty && step.skippedItems.isEmpty {
            Image(systemName: "checkmark").foregroundStyle(.tint)
        } else {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
        }
    }

    private func detail(for step: StepOutcome) -> String {
        if let reason = step.skippedReason { return reason }
        var parts: [String] = []
        let total = step.cleanedItemIDs.count + step.skippedItems.count + step.failures.count
        if !step.skippedItems.isEmpty {
            let done = step.cleanedItemIDs.count
            parts.append("\(verb(for: step.method)) \(done) of \(total) \(total == 1 ? "item" : "items"). \(step.skippedItems.count) skipped: changed since the scan.")
        } else if let first = step.failures.first {
            let more = step.failures.count > 1 ? " (and \(step.failures.count - 1) more in the log)" : ""
            parts.append(first + more)
        } else {
            switch step.method {
            case .delete: parts.append("Deleted. It is rebuilt or downloaded again when needed.")
            case .trash: parts.append("Moved to the Trash. Put Back returns it until the Trash is emptied.")
            case .command: parts.append("Removed by the tool that owns it.")
            case .adminCommand: parts.append("Removed with your password. The space comes back over the next minutes.")
            }
        }
        return parts.joined(separator: " ")
    }

    private func verb(for method: CleanMethod) -> String {
        switch method {
        case .delete: "Deleted"
        case .trash: "Moved"
        case .command, .adminCommand: "Removed"
        }
    }

    @ViewBuilder
    private func followUps(_ outcome: CleanOutcome) -> some View {
        let estimate = outcome.steps.filter { $0.succeeded && $0.method != .trash }.reduce(Int64(0)) { $0 + $1.size }
        let snapshotsDone = outcome.steps.contains { $0.method == .adminCommand && $0.skippedReason == nil && $0.failures.isEmpty }
        VStack(alignment: .leading, spacing: 16) {
            if let pending = model.putBackPending {
                PutBackCard(manifest: pending)
            }
            if let message = model.putBackMessage {
                PutBackMessage(text: message)
            }
            if snapshotsDone {
                followUp(
                    title: "Snapshots are gone, but macOS returns their space gradually",
                    text: "The space held by local snapshots comes back over the next minutes as APFS reclaims it. The number above will catch up on the next rescan.",
                    action: nil
                ) {}
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
                    text: needsYourCallText(outcome),
                    action: "Review Them"
                ) { model.showResults() }
            }
        }
    }

    private func needsYourCallText(_ outcome: CleanOutcome) -> String {
        var text = "These were not selected, or could not be removed this time."
        if outcome.skippedSize > 0 {
            text += " Quit what was open to include the \(ByteFormat.string(outcome.skippedSize)) that waited."
        }
        return text
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
