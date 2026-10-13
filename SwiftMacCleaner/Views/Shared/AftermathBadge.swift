//
//  AftermathBadge.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What you are left with once a group is removed: "Rebuilds itself", "Downloads again", "Cannot be
/// put back" or "Cannot be recreated". Every one looks the same, because it states a fact and does
/// not grade the group.
struct AftermathBadge: View {
    let aftermath: Aftermath

    var body: some View {
        Badge(text: aftermath.label)
            .help(aftermath.explanation)
    }
}
