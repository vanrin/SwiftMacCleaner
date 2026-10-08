//
//  ResultsHeadline.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// The sentence at the top of the results: how much was found, and what cleaning the ticked part would free.
struct ResultsHeadline: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let selected = model.selectedSize
        VStack(spacing: Design.Spacing.large) {
            Text("\(ByteFormat.string(model.foundSize)) found on \(model.disk.name)")
                .font(Design.Typeface.headline)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(Design.Typeface.tileBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 640)
            FreeSpaceForecast(now: model.disk.free, after: model.disk.free + selected)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Design.Spacing.medium)
    }

    private var detail: String {
        let places = model.findings.count == 1 ? "1 place" : "\(model.findings.count) places"
        var text = "In \(places). Rebuildable items are deleted right away. Everything else goes to the Trash first and can be put back."
        if !model.protected.isEmpty {
            text += " \(ByteFormat.string(model.protectedSize)) more was left alone on purpose, listed at the bottom."
        }
        return text
    }
}
