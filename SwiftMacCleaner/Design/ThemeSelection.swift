//
//  ThemeSelection.swift
//  SwiftMacCleaner
//

import SwiftUI

extension Area {
    /// The palette of this area's icon and of its own page. Neighbours in the sidebar never share one.
    var theme: Theme {
        switch self {
        case .xcode: .blue
        case .projects: .teal
        case .android: .green
        case .containers: .ocean
        case .packageCaches: .orange
        case .toolchains: .indigo
        case .ides: .magenta
        case .models: .rose
        case .cachesLogs: .green
        case .trash: .rose
        case .snapshots: .teal
        case .largeFiles: .amber
        case .leftovers: .blue
        case .installers: .ocean
        }
    }
}

extension SafetyTier {
    /// The colour of this tier's badge and bars. The tier's name is always written next to it.
    var color: Color {
        switch self {
        case .safe: Design.Signal.safe
        case .review: Design.Signal.review
        case .careful: .white
        }
    }
}

extension AreaGroup {
    /// The palette of this group's icon and of its page.
    var theme: Theme {
        switch self {
        case .system: .teal
        case .developer: .indigo
        }
    }
}

extension SidebarItem {
    /// The palette of this entry's icon and of its own screens.
    var theme: Theme {
        switch self {
        case .overview: .violet
        case .group(let group): group.theme
        case .area(let area): area.theme
        case .space: .ocean
        case .apps: .blue
        case .performance: .orange
        }
    }
}

extension AppModel {
    /// The palette for what is on screen. Each sidebar entry has its own, and a finished clean turns green.
    var theme: Theme {
        let item = sidebarSelection
        return switch item {
        case .space: item.theme
        case .apps: apps.phase == .done ? .green : item.theme
        case .performance: performance.phase == .done ? .green : item.theme
        case .group where phase == .results, .area where phase == .results: item.theme
        case .overview, .group, .area: phase == .done ? .green : SidebarItem.overview.theme
        }
    }
}
