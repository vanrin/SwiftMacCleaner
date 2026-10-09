//
//  SidebarToggleCommands.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The View menu's command for the sidebar, with the shortcut macOS uses for it everywhere.
struct SidebarToggleCommands: Commands {
    let settings: AppSettings

    var body: some Commands {
        CommandGroup(before: .sidebar) {
            Button(settings.isSidebarCollapsed ? "Expand Sidebar" : "Collapse Sidebar", action: settings.toggleSidebar)
                .keyboardShortcut("s", modifiers: [.control, .command])
        }
    }
}
