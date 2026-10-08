//
//  ItemRow.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// One thing that can be ticked inside a finding.
struct ItemRow: View {
    @Environment(AppModel.self) private var model
    let item: FindingItem
    let finding: Finding

    var body: some View {
        HStack(spacing: Design.Spacing.medium) {
            Toggle(isOn: model.binding(for: item)) {
                VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
                    Text(item.title)
                        .font(Design.Typeface.tileBody)
                        .lineLimit(1)
                    Text(item.detail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let hint = item.hint {
                        Text(hint)
                            .font(Design.Typeface.code)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
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
            Menu("More actions for \(item.title)", systemImage: "ellipsis") {
                ItemActions(item: item, finding: finding)
            }
            .labelStyle(.iconOnly)
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More")
        }
        .padding(.horizontal, Design.Spacing.large)
        .padding(.vertical, Design.Spacing.small)
        .contextMenu {
            ItemActions(item: item, finding: finding)
        }
    }

    private func showInFinder() {
        if let first = item.paths.first {
            model.showInFinder(first)
        }
    }
}
