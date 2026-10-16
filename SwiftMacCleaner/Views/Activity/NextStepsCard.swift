//
//  NextStepsCard.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Up to three things worth doing next, each with the part's icon and a way to it.
struct NextStepsCard: View {
    @Environment(AppModel.self) private var model
    var rowHeight = Design.Size.suggestionRow

    var body: some View {
        let suggestions = model.suggestions()
        ActivityCard(title: "Worth doing next", count: suggestions.isEmpty ? nil : suggestions.count) {
            if suggestions.isEmpty {
                Spacer(minLength: 0)
                VStack(spacing: Design.Spacing.small) {
                    ModuleIcon(symbol: .moduleActivity, theme: .graphite, size: Design.Size.tileIcon, depth: Design.Depth.tile)
                    Text("Nothing needs doing right now")
                        .font(Design.Typeface.rowTitle)
                    Text("Every part has been looked at lately, and nothing it found is waiting.")
                        .font(.callout)
                        .foregroundStyle(.quiet)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                        if index > 0 {
                            Divider()
                        }
                        row(suggestion)
                    }
                }
            }
        }
    }

    private func row(_ suggestion: ActivitySuggestion) -> some View {
        HStack(spacing: Design.Spacing.large - 2) {
            ModuleIcon(symbol: suggestion.item.icon, theme: suggestion.item.theme, size: 34, depth: Design.Depth.selected)
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.title)
                    .font(Design.Typeface.rowTitle)
                    .lineLimit(1)
                Text(suggestion.detail)
                    .font(.callout)
                    .foregroundStyle(.quiet)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button(suggestion.action, action: suggestion.perform)
                .buttonStyle(.compactPill)
                .accessibilityLabel(suggestion.actionLabel)
        }
        .frame(height: rowHeight)
    }
}
