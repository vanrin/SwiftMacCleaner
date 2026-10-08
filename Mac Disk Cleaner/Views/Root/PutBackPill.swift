//
//  PutBackPill.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// The title-bar notice that the last clean left things in the Trash that can still go back where they were.
struct PutBackPill: View {
    let model: AppModel
    let manifest: PutBack.Manifest

    var body: some View {
        let count = manifest.items.count
        let size = manifest.items.reduce(Int64(0)) { $0 + $1.size }
        NoticePill(
            title: "\(ByteFormat.string(size)) can be put back", symbol: "arrow.uturn.backward.circle.fill",
            text: "\(count == 1 ? "1 item" : "\(count) items") from your clean on \(manifest.date.formatted(date: .abbreviated, time: .shortened)) \(count == 1 ? "is" : "are") still in the Trash. Put Back returns every one of them to where it was. Emptying the Trash frees the space for good. Either way, this offer disappears once the Trash is emptied."
        ) {
            Button("Put Back \(count == 1 ? "1 Item" : "\(count) Items")", action: model.putBack)
            Button("Show Trash", action: model.openTrash)
        }
    }
}
