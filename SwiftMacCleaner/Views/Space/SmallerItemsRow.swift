//
//  SmallerItemsRow.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The last row of a folder: everything too small to list, added together.
struct SmallerItemsRow: View {
    @Environment(\.theme) private var theme
    let node: SpaceNode

    var body: some View {
        HStack(spacing: Design.Spacing.medium) {
            GlossyIcon(symbol: "ellipsis", theme: theme)
                .saturation(0.2)
            Text(node.children.isEmpty ? "Files and folders, none over 20 MB" : "Everything smaller than 20 MB")
                .foregroundStyle(.secondary)
            Spacer(minLength: Design.Spacing.medium)
            SizeBar(fraction: SpaceShare.fraction(of: node.smallerItemsSize, in: node.size), isActive: false,
                    width: Design.Size.shareBarWidth, alignment: .leading)
            Text(SpaceShare.text(of: node.smallerItemsSize, in: node.size))
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: Design.Size.percentColumn, alignment: .trailing)
            SizeLabel(bytes: node.smallerItemsSize, isEmphasized: false)
                .frame(width: Design.Size.sizeColumn, alignment: .trailing)
            // The chevron and the Finder button of the rows above, kept as empty space so the columns line up.
            Image(systemName: "chevron.right")
                .font(.callout)
                .hidden()
            Button("Show in Finder", systemImage: "magnifyingglass") {}
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .hidden()
        }
        .padding(.horizontal, Design.Spacing.large)
        .padding(.vertical, Design.Spacing.medium)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
