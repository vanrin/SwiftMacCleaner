//
//  SidebarButton.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One entry in the sidebar. Choosing it shows that part of the app.
struct SidebarButton: View {
    @Environment(AppModel.self) private var model
    let item: SidebarItem
    var badge: String?
    /// Dimmed while the entry leads nowhere, which is the case for areas before a scan.
    var isAvailable = true
    @State private var isHovered = false

    var body: some View {
        let isSelected = model.sidebarSelection.entry == item
        Button(action: select) {
            SidebarLabel(title: item.title, symbol: item.symbol, theme: item.theme, badge: badge,
                         isSelected: isSelected, isHovered: isHovered && isAvailable)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .onHover(perform: hover)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func select() {
        model.select(item)
    }

    private func hover(_ isInside: Bool) {
        isHovered = isInside
    }
}
