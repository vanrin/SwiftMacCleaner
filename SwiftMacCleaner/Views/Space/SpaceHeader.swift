//
//  SpaceHeader.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The folder on screen: its path, its size, and how much of the used disk that is.
struct SpaceHeader: View {
    @Environment(AppModel.self) private var model
    let node: SpaceNode

    var body: some View {
        HStack(alignment: .bottom, spacing: Design.Spacing.medium) {
            VStack(alignment: .leading, spacing: Design.Spacing.tight) {
                Text(model.space.displayPath(node.path))
                    .font(Design.Typeface.code)
                    .foregroundStyle(.quiet)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(ByteFormat.string(node.size))
                    .font(Design.Typeface.orbFigure)
                    .monospacedDigit()
                Text(footnote)
                    .foregroundStyle(.quiet)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: Design.Spacing.medium)
            Button("Show in Finder", action: showInFinder)
                .buttonStyle(.pill)
        }
    }

    private var footnote: String {
        let share = SpaceShare.text(of: node.size, in: model.disk.used)
        var footnote = "\(share) of the \(ByteFormat.string(model.disk.used)) in use on \(model.disk.name)"
        if node.isIncomplete { footnote += ". Some folders could not be read, so the real figure is higher" }
        return footnote
    }

    private func showInFinder() {
        model.showInFinder(URL(fileURLWithPath: node.path))
    }
}
