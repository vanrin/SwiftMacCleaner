//
//  SidebarView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The column on the left: the overview, the parts it runs in the order of its tiles, and the two it
/// leaves alone, Largest Folders and Duplicates, with My Activity and the settings at the foot. Every entry leads somewhere at any time. Folded
/// down, it is a rail of the same entries with their names left out. The entries stand together in the
/// middle of the room between the title bar and the foot, at any height of the window.
struct SidebarView: View {
    @Environment(AppModel.self) private var model
    var isCollapsed = false
    /// How tall the room for the entries is, between the title bar and the settings.
    @State private var roomHeight: Double = 0

    var body: some View {
        // The entries at the foot have room of their own. The sidebar has no pane, so a list that
        // scrolled underneath them would show through.
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Design.Spacing.large + Design.Spacing.tight) {
                    SidebarButton(item: .overview, isCollapsed: isCollapsed)
                    VStack(spacing: Design.Spacing.small) {
                        ForEach(model.overviewParts, id: \.self) { part in
                            SidebarButton(item: part, isCollapsed: isCollapsed)
                        }
                    }
                    // Apart from the rest: the overview's scan leaves these alone.
                    VStack(spacing: Design.Spacing.small) {
                        SidebarButton(item: .space, isCollapsed: isCollapsed)
                        SidebarButton(item: .duplicates, isCollapsed: isCollapsed)
                    }
                }
                .padding(.horizontal, Design.Spacing.small + Design.Spacing.tight / 2)
                .padding(.vertical, Design.Spacing.small)
                // At least as tall as the room, so the entries sit in its middle. When there are more
                // than fit, they start at the top and scroll.
                .frame(minHeight: roomHeight)
            }
            .onGeometryChange(for: Double.self) { proxy in
                proxy.size.height
            } action: { height in
                roomHeight = height
            }
            .scrollIndicators(.never)
            .scrollBounceBehavior(.basedOnSize)
            // The last entry in view fades out instead of being cut off.
            .mask {
                VStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: Design.Spacing.large)
                }
            }
            // About the app and the whole Mac rather than one part of it.
            VStack(spacing: Design.Spacing.small) {
                SidebarButton(item: .activity, isCollapsed: isCollapsed)
                SidebarSettingsLink(isCollapsed: isCollapsed)
            }
            .padding(.horizontal, Design.Spacing.small + Design.Spacing.tight / 2)
            .padding(.vertical, Design.Spacing.medium)
        }
    }
}
