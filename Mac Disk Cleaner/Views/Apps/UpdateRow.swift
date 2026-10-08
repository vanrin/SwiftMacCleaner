//
//  UpdateRow.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// One app with a newer version: what it would go from and to, when that came out, and what changed.
struct UpdateRow: View {
    @Environment(AppModel.self) private var model
    let app: InstalledApp
    let update: AppUpdate
    var showsDivider = true
    /// Release notes run long, so they are cut short until asked for.
    @State private var showsAllNotes = false

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.small) {
            HStack(spacing: Design.Spacing.medium) {
                AppIconView(url: app.url)
                VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
                    HStack(spacing: Design.Spacing.small) {
                        Text(app.name)
                            .font(Design.Typeface.rowTitle)
                            .lineLimit(1)
                        Text("\(update.installedVersion) → \(update.newVersion)")
                            .font(Design.Typeface.tileBody)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .accessibilityLabel("Version \(update.installedVersion) to \(update.newVersion)")
                    }
                    Text(detail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: Design.Spacing.medium)
                Button(update.feed == .appStore ? "Update in App Store" : "Open to Update", action: open)
                    .buttonStyle(.pill)
                    .accessibilityLabel(update.feed == .appStore ? "Update \(app.name) in the App Store" : "Open \(app.name) to update it")
                    .help(update.feed == .appStore
                          ? "Shows \(app.name) in the App Store, where the update is installed"
                          : "Opens \(app.name), whose own updater installs the update")
            }
            if let notes = update.notes {
                Button(action: toggleNotes) {
                    Text(notes)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(showsAllNotes ? nil : 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .padding(.leading, Design.Size.appIcon + Design.Spacing.medium)
                .accessibilityHint(showsAllNotes ? "Shows less" : "Shows all of what is new")
            }
        }
        .padding(.horizontal, Design.Spacing.large)
        .padding(.vertical, Design.Spacing.medium)
        .overlay(alignment: .top) {
            Divider()
                .opacity(showsDivider ? 1 : 0)
        }
    }

    /// Where the update comes from, when it came out, and how big the download is.
    private var detail: String {
        var parts = [update.feed.title]
        if let released = update.released { parts.append("Released \(released.formatted(date: .abbreviated, time: .omitted))") }
        if let size = update.size { parts.append(ByteFormat.string(size)) }
        return parts.joined(separator: " · ")
    }

    private func open() {
        model.apps.open(update)
    }

    private func toggleNotes() {
        showsAllNotes.toggle()
    }
}
