//
//  RootView.swift
//  SwiftMacCleaner
//

import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let theme = model.theme
        let isCollapsed = model.settings.isSidebarCollapsed
        HStack(spacing: 0) {
            SidebarView(isCollapsed: isCollapsed)
                .frame(width: isCollapsed ? Design.Size.sidebarRail : Design.Size.sidebar)
            SidebarDivider()
            DetailView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // The name of the rail entry under the pointer, drawn here because it reaches over the screen beside the rail.
        .overlayPreferenceValue(SidebarHintKey.self) { hint in
            SidebarHintOverlay(hint: hint)
        }
        .animation(reduceMotion ? nil : Design.Motion.sidebar, value: isCollapsed)
        // One backdrop for the whole window: the sidebar has no pane of its own.
        .containerBackground(for: .window) {
            ThemeBackdrop(theme: theme)
        }
        .toolbar {
            // First after the window buttons, and in the same place whichever way the sidebar is, so a
            // second click undoes the first.
            ToolbarItem(placement: .navigation) {
                SidebarToggle()
            }
        }
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .environment(\.theme, theme)
        .tint(theme.accent)
        // The backdrops are dark in every palette, so the window is too, whatever the system setting.
        .preferredColorScheme(.dark)
        .typesettingLanguage(Design.language)
        .frame(minWidth: Design.Size.minimumWindowWidth, minHeight: Design.Size.minimumWindowHeight)
    }
}
