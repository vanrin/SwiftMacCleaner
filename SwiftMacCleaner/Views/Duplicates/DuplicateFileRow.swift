//
//  DuplicateFileRow.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One copy in a group: its name, the folder it is in, when it was last changed, and whether it stays.
struct DuplicateFileRow: View {
    @Environment(AppModel.self) private var model
    let file: DuplicateFile
    let group: DuplicateGroup

    var body: some View {
        let duplicates = model.duplicates
        let canToggle = duplicates.canToggle(file, in: group)
        HStack(spacing: Design.Spacing.medium) {
            if canToggle {
                Toggle(isOn: duplicates.binding(for: file, in: group)) {
                    name
                }
                .toggleStyle(.check)
            } else {
                // The copy that stays is the one the user most needs to read, so only its box is dimmed.
                HStack(spacing: Design.Spacing.medium) {
                    CheckMark(isOn: false)
                        .opacity(0.4)
                    name
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue("Stays")
                .help(staysReason)
                Badge(text: "Stays", style: file.isLocked ? .neutral : .new)
                    .help(staysReason)
            }
            if file.sharesSpace {
                Badge(text: "Shares its space")
                    .help("A clone: it points at the same data as \(file.storage.cloneCount == 2 ? "another file" : "\(file.storage.cloneCount - 1) other files"), so removing it alone gives nothing back.")
            }
            Spacer(minLength: Design.Spacing.medium)
            if let modified = file.modified {
                Text(modified.formatted(date: .abbreviated, time: .omitted))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help("Last changed \(modified.formatted(date: .long, time: .shortened))")
            }
            Button("Show \(file.url.lastPathComponent) in Finder", systemImage: "magnifyingglass", action: showInFinder)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Show in Finder")
        }
        .padding(.leading, Design.Spacing.large)
        .padding(.trailing, Design.Spacing.large)
        .padding(.vertical, Design.Spacing.small)
        .contextMenu {
            Button("Show in Finder", action: showInFinder)
            Button("Copy Path", action: copyPath)
            if !file.isLocked {
                Divider()
                Button("Never Suggest Files in “\(file.url.deletingLastPathComponent().lastPathComponent)”", action: neverSuggest)
            }
        }
    }

    /// The file's name over the folder it is in.
    private var name: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(file.url.lastPathComponent)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(model.duplicates.displayPath(file.url.deletingLastPathComponent()))
                .font(Design.Typeface.code)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    /// Why the box cannot be ticked: the copy has to stay, or it is the last one left unticked.
    private var staysReason: String {
        file.lockedReason.map { "\($0)." } ?? "One copy always stays. Untick another copy to remove this one instead."
    }

    private func showInFinder() {
        model.showInFinder(file.url)
    }

    private func copyPath() {
        model.copyPath(file.url)
    }

    private func neverSuggest() {
        model.duplicates.neverSuggest(folderOf: file)
    }
}
