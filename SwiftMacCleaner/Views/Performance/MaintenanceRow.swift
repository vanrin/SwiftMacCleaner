//
//  MaintenanceRow.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One maintenance task: a tick box, what it does or why it is worth running now, and the full story
/// behind an info button.
struct MaintenanceRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let check: MaintenanceCheck
    var showsDivider = true
    @State private var showingInfo = false

    var body: some View {
        let performance = model.performance
        let task = check.task
        let isBlocked = performance.isBlocked(task)
        HStack(spacing: Design.Spacing.medium) {
            Toggle(isOn: performance.binding(for: task)) {
                Text(task.title)
            }
            .toggleStyle(.checkOnly)
            .disabled(!check.isAvailable)
            FeatureIcon(Image(systemName: task.symbol), theme: theme, size: Design.Size.appIcon, isTinted: check.isAvailable)
            VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
                HStack(spacing: Design.Spacing.small) {
                    Text(task.title)
                        .font(Design.Typeface.rowTitle)
                        .lineLimit(1)
                    if check.isRecommended {
                        Badge(text: "Recommended", style: .new)
                    }
                    if task.needsPassword, check.isAvailable {
                        Badge(text: "Asks for your password", style: .password)
                    }
                    if isBlocked, check.isAvailable {
                        Badge(text: task.waitsFor?.badge ?? "Waits", style: .waits)
                    }
                }
                Text(check.unavailable ?? check.reason ?? task.summary)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: Design.Spacing.medium)
            if check.size > 0 {
                SizeLabel(bytes: check.size)
            }
            Button("About \(task.title)", systemImage: "info.circle", action: showInfo)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("What this task does")
                .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
                    VStack(alignment: .leading, spacing: Design.Spacing.medium) {
                        Text(task.title)
                            .font(.headline)
                        Text(task.explanation)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(lastRun)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(Design.Spacing.large)
                    .frame(width: Design.Size.noticeWidth)
                }
        }
        .foregroundStyle(check.isAvailable ? .primary : .secondary)
        .padding(.horizontal, Design.Spacing.large)
        .padding(.vertical, Design.Spacing.medium)
        .overlay(alignment: .top) {
            Divider()
                .opacity(showsDivider ? 1 : 0)
        }
    }

    private var lastRun: String {
        guard let date = check.lastRun else { return "Never run from here." }
        return "Last run from here \(date.formatted(date: .abbreviated, time: .shortened))."
    }

    private func showInfo() {
        showingInfo = true
    }
}
