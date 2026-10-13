//
//  FullDiskAccessNote.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Shown when Downloads, Documents, Desktop or the Trash could not be read.
struct FullDiskAccessNote: View {
    @Environment(AppModel.self) private var model
    /// The folders macOS kept private, named the way the user knows them.
    let folders: [String]

    var body: some View {
        let names = ListFormat.string(folders)
        Notice(
            symbol: "lock.fill",
            title: "\(names.prefix(1).uppercased() + names.dropFirst()) could not be scanned",
            text: "macOS keeps \(folders.count == 1 ? "it" : "them") private. Everything else was scanned. Grant Full Disk Access in Privacy & Security, then scan again."
        ) {
            Button("Open Privacy Settings", action: model.openFullDiskAccessSettings)
                .buttonStyle(.pill)
        }
    }
}
