//
//  SidebarView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The column on the left: the overview, the parts it runs in the order of its tiles, and Largest
/// Folders, with the settings alone at the foot. Every entry leads somewhere at any time. Folded
/// down, it is a rail of the same entries with their names left out.
struct SidebarView: View {
    @Environment(AppModel.self) private var model
    var isCollapsed = false

    var body: some View {
        // The entry at the foot has room of its own. The sidebar has no pane, so a list that scrolled
        // underneath it would show through.
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Design.Spacing.medium) {
                    SidebarButton(item: .overview, isCollapsed: isCollapsed)
                    VStack(spacing: Design.Spacing.tight / 2) {
                        ForEach(model.overviewParts, id: \.self) { part in
                            SidebarButton(item: part, isCollapsed: isCollapsed)
                        }
                    }
                    // Apart from the rest: the overview's scan leaves it alone.
                    SidebarButton(item: .space, isCollapsed: isCollapsed)
                }
                .padding(.horizontal, Design.Spacing.small + Design.Spacing.tight / 2)
                .padding(.vertical, Design.Spacing.small)
            }
            .scrollIndicators(.never)
            // The last entry in view fades out instead of being cut off.
            .mask {
                VStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: Design.Spacing.large)
                }
            }
            SidebarSettingsLink(isCollapsed: isCollapsed)
                .padding(.horizontal, Design.Spacing.small + Design.Spacing.tight / 2)
                .padding(.vertical, Design.Spacing.medium)
        }
    }
}
