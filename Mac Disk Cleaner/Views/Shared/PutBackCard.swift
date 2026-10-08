//
//  PutBackCard.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// The last clean left things in the Trash that can still go back where they were.
struct PutBackCard: View {
    @Environment(AppModel.self) private var model
    let manifest: PutBack.Manifest

    var body: some View {
        let count = manifest.items.count
        let size = manifest.items.reduce(Int64(0)) { $0 + $1.size }
        Notice(
            symbol: "arrow.uturn.backward.circle.fill",
            isHighlighted: true,
            title: "\(ByteFormat.string(size)) is in the Trash and can still be put back",
            text: "\(count == 1 ? "1 item" : "\(count) items") from your clean on \(manifest.date.formatted(date: .abbreviated, time: .shortened)). Put Back returns every one of them to where it was. Emptying the Trash frees the space for good. Either way, this offer disappears once the Trash is emptied."
        ) {
            VStack(alignment: .trailing, spacing: Design.Spacing.small) {
                Button("Put Back \(count == 1 ? "1 Item" : "\(count) Items")", action: model.putBack)
                    .buttonStyle(.primaryPill)
                Button("Show Trash", action: model.openTrash)
                    .buttonStyle(.pill)
            }
        }
    }
}
