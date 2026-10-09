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
    @State private var isHovered = false

    var body: some View {
        let isSelected = model.sidebarSelection == item
        let isBusy = item == .overview ? model.overviewPhase == .scanning : model.isScanning(item)
        Button(action: select) {
            SidebarLabel(title: item.title, glyph: item.glyph, theme: item.theme, badge: badge,
                         isSelected: isSelected, isHovered: isHovered, isBusy: isBusy)
        }
        .buttonStyle(.plain)
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
