//
//  LeftoverRow.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One leftover that can be ticked: an installer, or the files of an app that is gone.
struct LeftoverRow: View {
    @Environment(AppModel.self) private var model
    let item: FindingItem

    var body: some View {
        HStack(spacing: Design.Spacing.medium) {
            Toggle(isOn: model.apps.binding(for: item)) {
                VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
                    Text(item.title)
                        .font(Design.Typeface.tileBody)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(item.detail)
                        .foregroundStyle(.quiet)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .toggleStyle(.check)
            Spacer(minLength: Design.Spacing.medium)
            SizeLabel(bytes: item.size, unknown: item.sizeUnknown)
            if item.paths.first != nil {
                Button("Show \(item.title) in Finder", systemImage: "magnifyingglass", action: showInFinder)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Show in Finder")
            }
        }
        .padding(.horizontal, Design.Spacing.large)
        .padding(.vertical, Design.Spacing.small)
        .contextMenu {
            if let first = item.paths.first {
                Button("Show in Finder", action: showInFinder)
                Button("Copy Path") { model.copyPath(first) }
            }
        }
    }

    private func showInFinder() {
        if let first = item.paths.first {
            model.showInFinder(first)
        }
    }
}
