//
//  SidebarToggle.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The title-bar button that folds the sidebar down to its glyphs and opens it out again.
struct SidebarToggle: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let settings = model.settings
        Button(settings.isSidebarCollapsed ? "Expand Sidebar" : "Collapse Sidebar", systemImage: "sidebar.left",
               action: settings.toggleSidebar)
            .help(settings.isSidebarCollapsed ? "Show the names beside the icons" : "Fold the sidebar down to its icons")
    }
}
