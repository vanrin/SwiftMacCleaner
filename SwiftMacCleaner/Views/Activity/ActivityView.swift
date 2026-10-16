//
//  ActivityView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// My Activity: what the app has done on this Mac, added up on cards, and every run of it in History.
struct ActivityView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let activity = model.activity
        Group {
            if activity.showsHistory {
                ActivityHistory()
            } else {
                ActivityPage()
            }
        }
        .toolbar {
            if activity.showsHistory {
                ToolbarItem(placement: .navigation) {
                    Button("My Activity", systemImage: "chevron.left", action: activity.showCards)
                        .labelStyle(.titleBar)
                        .help("Back to what it all adds up to")
                }
            }
        }
    }
}

extension ActivityRecord.Part {
    /// The sidebar entry that stands for this part, whose icon and colours it wears.
    var item: SidebarItem {
        switch self {
        case .overview: .overview
        case .system: .group(.system)
        case .developer: .group(.developer)
        case .largeFiles: .group(.largeFiles)
        case .apps: .apps
        case .performance: .performance
        case .duplicates: .duplicates
        }
    }
}
