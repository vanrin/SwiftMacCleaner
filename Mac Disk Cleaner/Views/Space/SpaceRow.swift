//
//  SpaceRow.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// One file or folder inside the folder on screen. A folder opens when clicked.
struct SpaceRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let node: SpaceNode
    let parentSize: Int64
    var showsDivider = true

    private var canOpen: Bool { node.isDirectory && !node.isUnreadable }

    var body: some View {
        HStack(spacing: Design.Spacing.medium) {
            Button(action: open) {
                HStack(spacing: Design.Spacing.medium) {
                    GlossyIcon(symbol: symbol, theme: theme)
                        .saturation(node.isUnreadable ? 0.2 : 1)
                    VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
                        Text(node.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if !note.isEmpty {
                            Text(note)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: Design.Spacing.medium)
                    SizeBar(fraction: SpaceShare.fraction(of: node.size, in: parentSize), width: Design.Size.shareBarWidth,
                            alignment: .leading)
                        .opacity(node.isUnreadable ? 0 : 1)
                    Text(node.isUnreadable ? "" : SpaceShare.text(of: node.size, in: parentSize))
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: Design.Size.percentColumn, alignment: .trailing)
                    SizeLabel(bytes: node.size, unknown: node.isUnreadable)
                        .frame(width: Design.Size.sizeColumn, alignment: .trailing)
                    Image(systemName: "chevron.right")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .opacity(canOpen ? 1 : 0)
                        .accessibilityHidden(true)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .allowsHitTesting(canOpen)
            .accessibilityHint(canOpen ? "Shows what is inside" : "")

            Button("Show \(node.name) in Finder", systemImage: "magnifyingglass", action: showInFinder)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Show in Finder")
        }
        .padding(.horizontal, Design.Spacing.large)
        .padding(.vertical, Design.Spacing.medium)
        .overlay(alignment: .top) {
            Divider()
                .opacity(showsDivider ? 1 : 0)
        }
    }

    private var symbol: String {
        if node.isUnreadable {
            "lock"
        } else if node.isDirectory {
            "folder"
        } else {
            "doc"
        }
    }

    /// The line under the name: what the folder is, or why its size is not the whole story.
    private var note: String {
        if node.isUnreadable {
            "macOS would not let the app look inside"
        } else if node.isDirectory, let friendlyName = SpaceScanner.friendlyName(forFolderAt: node.path) {
            friendlyName
        } else if node.isIncomplete {
            "Part of it could not be read, so this is a lower bound"
        } else {
            ""
        }
    }

    private func open() {
        model.space.open(node)
    }

    private func showInFinder() {
        model.showInFinder(URL(fileURLWithPath: node.path))
    }
}
