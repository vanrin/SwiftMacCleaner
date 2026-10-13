//
//  BackgroundItemRow.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One launch agent or daemon: the app it belongs to when there is one, what it is, when it runs, and
/// whether it is running now.
struct BackgroundItemRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let item: BackgroundItem
    var showsDivider = true

    var body: some View {
        let performance = model.performance
        HStack(spacing: Design.Spacing.medium) {
            Toggle(isOn: performance.binding(for: item)) {
                Text(item.title)
            }
            .toggleStyle(.checkOnly)
            if let app = item.appURL {
                AppIconView(url: app)
            } else {
                FeatureIcon(Image(systemName: "gearshape.2"), theme: theme, size: Design.Size.appIcon)
            }
            VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
                HStack(spacing: Design.Spacing.small) {
                    Text(item.title)
                        .font(Design.Typeface.rowTitle)
                        .lineLimit(1)
                    if item.isRunning {
                        Badge(text: "Running")
                    } else if item.isDisabled {
                        Badge(text: "Disabled")
                    }
                    if item.needsPassword {
                        Badge(text: "Asks for your password", style: .password)
                    }
                }
                Text(item.detail)
                    .foregroundStyle(.quiet)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: Design.Spacing.medium)
            Button("Show \(item.plist.lastPathComponent) in Finder", systemImage: "magnifyingglass", action: showInFinder)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Show its plist in Finder")
        }
        .padding(.horizontal, Design.Spacing.large)
        .padding(.vertical, Design.Spacing.medium)
        .overlay(alignment: .top) {
            Divider()
                .opacity(showsDivider ? 1 : 0)
        }
        .contextMenu {
            Button("Show in Finder", action: showInFinder)
            Button("Copy Path") { model.copyPath(item.plist) }
            if let program = item.program {
                Button("Copy Program Path") { model.copyPath(URL(fileURLWithPath: program)) }
            }
        }
    }

    private func showInFinder() {
        model.performance.showInFinder(item.plist)
    }
}
