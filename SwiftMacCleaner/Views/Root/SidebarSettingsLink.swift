//
//  SidebarSettingsLink.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The entry at the foot of the sidebar that opens the settings window.
struct SidebarSettingsLink: View {
    var isCollapsed = false
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        SettingsLink {
            SidebarLabel(title: "Settings", symbol: .moduleSettings, theme: .graphite, isHovered: isHovered, isCollapsed: isCollapsed)
        }
        .buttonStyle(.sidebarEntry)
        .focused($isFocused)
        .onHover(perform: hover)
        .sidebarHint("Settings", isShown: isCollapsed && (isHovered || isFocused))
        .accessibilityLabel("Settings")
    }

    private func hover(_ isInside: Bool) {
        isHovered = isInside
    }
}
