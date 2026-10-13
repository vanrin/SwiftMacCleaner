//
//  SidebarButton.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One entry in the sidebar. Choosing it shows that part of the app.
struct SidebarButton: View {
    @Environment(AppModel.self) private var model
    let item: SidebarItem
    var isCollapsed = false
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        let status = model.sidebarStatus(of: item)
        let isSelected = model.sidebarSelection == item
        let isBusy = item == .overview ? model.overviewPhase == .scanning : model.isScanning(item)
        Button(action: select) {
            SidebarLabel(title: item.title, symbol: item.icon, theme: item.theme, badge: status.badge,
                         isSelected: isSelected, isHovered: isHovered, isBusy: isBusy,
                         isCollapsed: isCollapsed, hasFindings: status.hasFindings)
        }
        .buttonStyle(.sidebarEntry)
        .focused($isFocused)
        .onHover(perform: hover)
        .sidebarHint(item.title, detail: status.hint, isShown: isCollapsed && (isHovered || isFocused))
        // Said outright, because on the rail the name and the figure are out of sight and would go unread.
        .accessibilityLabel(item.title)
        .accessibilityValue(status.badge ?? "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func select() {
        model.select(item)
    }

    private func hover(_ isInside: Bool) {
        isHovered = isInside
    }
}
