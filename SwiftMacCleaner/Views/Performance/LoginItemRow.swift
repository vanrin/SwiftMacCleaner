//
//  LoginItemRow.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One login item: the app's icon and name, where it is, and whether it opens hidden or is no longer there.
struct LoginItemRow: View {
    @Environment(AppModel.self) private var model
    let item: LoginItem
    var showsDivider = true

    var body: some View {
        let performance = model.performance
        HStack(spacing: Design.Spacing.medium) {
            Toggle(isOn: performance.binding(for: item)) {
                Text(item.name)
            }
            .toggleStyle(.checkOnly)
            AppIconView(url: item.path)
                .saturation(item.exists ? 1 : 0.3)
            VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
                HStack(spacing: Design.Spacing.small) {
                    Text(item.name)
                        .font(Design.Typeface.rowTitle)
                        .lineLimit(1)
                    if item.isHidden {
                        Badge(text: "Opens hidden")
                    }
                    if !item.exists {
                        Badge(text: "App is missing", style: .waits)
                    }
                }
                Text(item.exists ? performance.displayPath(item.path) : "The app is no longer at \(performance.displayPath(item.path)), so this item opens nothing.")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: Design.Spacing.medium)
            if item.exists {
                Button("Show \(item.name) in Finder", systemImage: "magnifyingglass", action: showInFinder)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Show in Finder")
            }
        }
        .padding(.horizontal, Design.Spacing.large)
        .padding(.vertical, Design.Spacing.medium)
        .overlay(alignment: .top) {
            Divider()
                .opacity(showsDivider ? 1 : 0)
        }
        .contextMenu {
            if item.exists {
                Button("Show in Finder", action: showInFinder)
            }
            Button("Copy Path") { model.copyPath(item.path) }
        }
    }

    private func showInFinder() {
        model.performance.showInFinder(item.path)
    }
}
