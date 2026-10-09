//
//  RootView.swift
//  SwiftMacCleaner
//

import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let theme = model.theme
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: Design.Size.sidebar)
            SidebarDivider()
            DetailView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // One backdrop for the whole window: the sidebar has no pane of its own.
        .containerBackground(for: .window) {
            ThemeBackdrop(theme: theme)
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
