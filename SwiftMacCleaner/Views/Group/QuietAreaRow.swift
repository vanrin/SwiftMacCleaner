//
//  QuietAreaRow.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One area of a group the scan offered nothing in: whether it was clean, skipped or not looked at, and why.
struct QuietAreaRow: View {
    @Environment(AppModel.self) private var model
    let area: Area

    var body: some View {
        let kept = model.protected(in: area)
        HStack(spacing: Design.Spacing.medium) {
            // Nothing to clean here, so the lens stays clear.
            FeatureIcon(Image(area.glyph), theme: area.theme, isTinted: false)
            TitledDetail(title: area.title, detail: reason(kept: kept.count))
            Spacer(minLength: Design.Spacing.medium)
            Badge(text: state)
            // The area's own page has something to show only when the scan left things alone there.
            if !kept.isEmpty {
                Button("Details for \(area.title)", systemImage: "chevron.right", action: showDetails)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Show what was left alone")
            }
        }
        .padding(.horizontal, Design.Spacing.large)
        .padding(.vertical, Design.Spacing.medium)
    }

    private var state: String {
        switch model.areaState(for: area) {
        case .skipped: "Skipped"
        case .idle: "Not scanned"
        case .queued, .scanning, .finished: "Clean"
        }
    }

    private func reason(kept: Int) -> String {
        switch model.areaState(for: area) {
        case .skipped(let reason):
            reason
        case .idle:
            "It was not part of the last scan."
        case .queued, .scanning, .finished:
            switch kept {
            case 0: "The scan found nothing worth removing here."
            case 1: "1 thing was found and left alone on purpose."
            default: "\(kept) things were found and left alone on purpose."
            }
        }
    }

    private func showDetails() {
        model.select(.area(area))
    }
}
