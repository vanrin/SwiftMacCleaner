//
//  ItemRow.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One thing that can be ticked inside a finding.
struct ItemRow: View {
    @Environment(AppModel.self) private var model
    @Environment(CleanUpModel.self) private var cleanUp
    let item: FindingItem
    let finding: Finding

    var body: some View {
        HStack(spacing: Design.Spacing.medium) {
            Toggle(isOn: cleanUp.binding(for: item)) {
                VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
                    Text(item.title)
                        .font(Design.Typeface.tileBody)
                        .lineLimit(1)
                    Text(item.detail)
                        .foregroundStyle(.quiet)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let hint = item.hint {
                        Text(hint)
                            .font(Design.Typeface.code)
                            .foregroundStyle(.quiet)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .toggleStyle(.check)
            Spacer(minLength: Design.Spacing.medium)
            if let keeper = cleanUp.keepers(of: item).first {
                Badge(text: "\(keeper.name) is open", style: .waits)
                    .help("Its cache waits until \(keeper.name) has quit. The confirmation offers to ask it to")
            }
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
