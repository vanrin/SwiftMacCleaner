//
//  AppRow.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// One installed app: a tick box for the app and everything it keeps, when it was last opened, and how
/// much it takes up in all. Clicking the row lists its files under it.
struct AppRow: View {
    @Environment(AppModel.self) private var model
    let app: InstalledApp
    var showsDivider = true

    var body: some View {
        let apps = model.apps
        let isExpanded = apps.isExpanded(app)
        HStack(spacing: Design.Spacing.medium) {
            Toggle(sources: apps.bindings(for: app.files), isOn: \.self) {
                Text("\(app.name) and its files")
            }
            .toggleStyle(.checkOnly)
            Button(action: toggle) {
                HStack(spacing: Design.Spacing.medium) {
                    AppIconView(url: app.url)
                    VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
                        HStack(spacing: Design.Spacing.small) {
                            Text(app.name)
                                .font(Design.Typeface.rowTitle)
                                .lineLimit(1)
                            if apps.isRunning(app) {
                                Badge(text: "Open", style: .waits)
                            }
                            if apps.update(for: app) != nil {
                                Badge(text: "Update", style: .new)
                            }
                        }
                        Text(detail)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: Design.Spacing.medium)
                    SizeLabel(bytes: app.size)
                    Image(systemName: "chevron.right")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Hides its files" : "Shows its files")
        }
        .padding(.horizontal, Design.Spacing.large)
        .padding(.vertical, Design.Spacing.medium)
        .overlay(alignment: .top) {
            Divider()
                .opacity(showsDivider ? 1 : 0)
        }
        .contextMenu {
            Button("Show in Finder", action: showInFinder)
            Button("Copy Path", action: copyPath)
        }
    }

    /// When it was last opened, its version, and where it came from.
    private var detail: String {
        var parts = [app.lastOpened.map { "Opened \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "Never opened"]
        if !app.version.isEmpty { parts.append("Version \(app.version)") }
        if app.source == .appStore { parts.append("App Store") }
        return parts.joined(separator: " · ")
    }

    private func toggle() {
        withAnimation(.snappy) {
            model.apps.toggleExpanded(app)
        }
    }

    private func showInFinder() {
        model.showInFinder(app.url)
    }

    private func copyPath() {
        model.copyPath(app.url)
    }
}
