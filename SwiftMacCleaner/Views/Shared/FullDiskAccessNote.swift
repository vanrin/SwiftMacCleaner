//
//  FullDiskAccessNote.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Shown when Downloads or the Trash could not be read.
struct FullDiskAccessNote: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let folders = model.unreadableFolders.joined(separator: " and ")
        Notice(
            symbol: "lock.fill",
            title: "\(folders.prefix(1).uppercased() + folders.dropFirst()) could not be scanned",
            text: "macOS keeps \(model.unreadableFolders.count == 1 ? "it" : "them") private. Everything else was scanned. Grant Full Disk Access in Privacy & Security, then scan again."
        ) {
            Button("Open Privacy Settings", action: model.openFullDiskAccessSettings)
                .buttonStyle(.pill)
        }
    }
}
