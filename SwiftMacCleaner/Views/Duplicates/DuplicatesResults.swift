//
//  DuplicatesResults.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What the scan found: a column that narrows the list to one kind of file, and beside it the groups of
/// identical files. What is ticked is moved to the Trash with the round button.
struct DuplicatesResults: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var duplicates = model.duplicates
        let shown = duplicates.visibleGroups
        HStack(alignment: .top, spacing: Design.Spacing.xLarge) {
            DuplicatesColumn()
                .frame(width: Design.Size.filterColumn)
            VStack(alignment: .leading, spacing: Design.Spacing.large) {
                PaneHeading(title: duplicates.kind?.title ?? "All Duplicates", detail: detail(duplicates)) {
                    SearchField(text: $duplicates.search, prompt: "Search names and folders")
                    Spacer(minLength: 0)
                    Menu("Select") {
                        Button("Extra Copies", action: duplicates.selectExtras)
                        Button("None", action: duplicates.selectNone)
                    }
                    .fixedSize()
                    .help("Extra Copies ticks every copy but the one most worth keeping, in each group shown")
                    Picker("Sort by", selection: $duplicates.sort) {
                        ForEach(DuplicatesModel.Sort.allCases) { sort in
                            Text("By \(sort.title)").tag(sort)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .help("How the groups are ordered")
                }
                if shown.isEmpty, duplicates.scan.unreadable.isEmpty {
                    ContentUnavailableView {
                        Label(emptyTitle(duplicates), systemImage: "doc.on.doc")
                    } description: {
                        Text(emptyDetail(duplicates))
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: Design.Spacing.large) {
                            ForEach(shown) { group in
                                DuplicateGroupCard(group: group)
                            }
                            if !duplicates.scan.unreadable.isEmpty {
                                Notice(
                                    symbol: "lock.fill",
                                    title: unreadableTitle(duplicates.scan.unreadable),
                                    text: "macOS keeps \(duplicates.scan.unreadable.count == 1 ? "it" : "them") private, so nothing there was compared. Grant Full Disk Access in Privacy & Security, then scan again."
                                ) {
                                    Button("Open Privacy Settings", action: model.openFullDiskAccessSettings)
                                        .buttonStyle(.pill)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, Design.Spacing.pageHorizontal)
        .padding(.top, Design.Spacing.pageVertical)
        .frame(maxWidth: 1100)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .orbAction {
            DuplicatesRemoveButton()
        }
    }

    /// The sentence under the heading: how many groups, and what keeping one copy of each gives back.
    private func detail(_ duplicates: DuplicatesModel) -> String {
        let groups = duplicates.groups(of: duplicates.kind)
        guard !groups.isEmpty else { return "Nothing in \(duplicates.scannedTitle) is there twice." }
        let gain = groups.reduce(Int64(0)) { $0 + $1.reclaimable }
        var text = "\(groups.count == 1 ? "1 group" : "\(groups.count.formatted()) groups") of identical files in \(duplicates.scannedTitle). "
        text += gain > 0
            ? "Keeping one copy of each gives back \(ByteFormat.string(gain))."
            : "The copies share their space, so removing them tidies up and gives nothing back."
        if duplicates.kind == nil, duplicates.scan.cloudOnly > 0 {
            text += " \(duplicates.scan.cloudOnly == 1 ? "1 item" : "\(duplicates.scan.cloudOnly.formatted()) items") kept only in iCloud \(duplicates.scan.cloudOnly == 1 ? "was" : "were") not downloaded to be compared."
        }
        return text
    }

    private func unreadableTitle(_ paths: [String]) -> String {
        let names = paths.prefix(3).map { model.duplicates.displayPath(URL(fileURLWithPath: $0)) }
        let more = paths.count > 3 ? " and \(paths.count - 3) more" : ""
        return "\(names.joined(separator: ", "))\(more) could not be read"
    }

    private func emptyTitle(_ duplicates: DuplicatesModel) -> String {
        duplicates.search.trimmingCharacters(in: .whitespaces).isEmpty ? "No duplicates" : "No duplicate matches"
    }

    private func emptyDetail(_ duplicates: DuplicatesModel) -> String {
        if !duplicates.search.trimmingCharacters(in: .whitespaces).isEmpty {
            return "No file in this list has “\(duplicates.search)” in its name or its folder."
        }
        return "No two files of 100 KB or more in \(duplicates.scannedTitle) are the same."
    }
}
