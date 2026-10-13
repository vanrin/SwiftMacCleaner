//
//  SearchField.swift
//  SwiftMacCleaner
//

import SwiftUI

/// A glass field for narrowing a list by name.
struct SearchField: View {
    @Binding var text: String
    /// What the empty field says it looks through.
    var prompt = "Search"

    var body: some View {
        HStack(spacing: Design.Spacing.small) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.quiet)
                .accessibilityHidden(true)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button("Clear search", systemImage: "xmark.circle.fill", action: clear)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.quiet)
            }
        }
        .padding(.horizontal, Design.Spacing.medium)
        .padding(.vertical, Design.Spacing.small)
        .frame(minWidth: Design.Size.searchFieldMinimum, maxWidth: Design.Size.searchField)
        .background {
            RoundedRectangle(cornerRadius: Design.Radius.control)
                .fill(Design.Surface.well)
                .strokeBorder(Design.Surface.panelBorder)
        }
    }

    private func clear() {
        text = ""
    }
}
