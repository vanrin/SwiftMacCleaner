//
//  AppsSearchField.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// A glass field for narrowing a list of apps by name.
struct AppsSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: Design.Spacing.small) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search apps", text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button("Clear search", systemImage: "xmark.circle.fill", action: clear)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
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
