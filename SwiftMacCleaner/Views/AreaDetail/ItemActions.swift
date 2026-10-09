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
    }

    private func neverSuggest() {
        cleanUp.neverSuggest(item, in: finding)
    }
}
