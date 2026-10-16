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
        case .packageCaches: .amber
        case .toolchains: .indigo
        case .ides: .violet
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

extension AreaGroup {
    /// The palette of this group's icon and of its page.
    var theme: Theme {
        switch self {
        case .system: .teal
        case .developer: .indigo
        case .largeFiles: .amber
        }
    }
}

extension SidebarItem {
    /// The palette of this entry's icon and of its own screens.
    var theme: Theme {
        switch self {
        case .overview, .activity: .graphite
        case .group(let group): group.theme
        case .space: .ocean
        case .duplicates: .violet
        case .apps: .blue
        case .performance: .rose
        case .protection: .green
        }
    }
}

extension AppModel {
    /// The palette for what is on screen. Each sidebar entry has its own, and a finished clean has the green one.
    var theme: Theme {
        let item = sidebarSelection
        return switch item {
        case .space, .protection, .activity: item.theme
        case .duplicates: duplicates.phase == .done ? .done : item.theme
        case .apps: apps.phase == .done ? .done : item.theme
        case .performance: performance.phase == .done ? .done : item.theme
        case .group(let group): cleanUp(group).phase == .done ? .done : item.theme
        case .overview: overviewPhase == .done ? .done : item.theme
        }
    }
}
