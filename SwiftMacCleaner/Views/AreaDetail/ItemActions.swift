//
//  ItemActions.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What the row menu and the right-click menu of an item both offer.
struct ItemActions: View {
    @Environment(AppModel.self) private var model
    @Environment(CleanUpModel.self) private var cleanUp
    let item: FindingItem
    let finding: Finding

    var body: some View {
        if let first = item.paths.first {
            Button("Show in Finder") { model.showInFinder(first) }
            Button("Copy Path") { model.copyPath(first) }
            Divider()
        }
        Button("Never Suggest This", action: neverSuggest)
        // A large file sits in a folder of the user's own, which may hold more they would rather not be asked about.
        if finding.area == .largeFiles, let folder = item.paths.first?.deletingLastPathComponent() {
            Button("Never Suggest Files in “\(folder.lastPathComponent)”", action: neverSuggestFolder)
        }
    }

    private func neverSuggest() {
        cleanUp.neverSuggest(item, in: finding)
    }

    private func neverSuggestFolder() {
        cleanUp.neverSuggest(folderOf: item, in: finding)
    }
}
