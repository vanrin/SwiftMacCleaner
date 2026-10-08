//
//  ThemeSelection.swift
//  Mac Disk Cleaner
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
        case .installersTrash: .amber
        case .leftovers: .blue
        case .snapshots: .teal
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

extension AppModel {
    /// The palette for what is on screen. Each sidebar entry has its own, and a finished clean turns green.
    var theme: Theme {
        switch sidebarSelection {
        case .space: .ocean
        case .apps: apps.phase == .done ? .green : .blue
        case .area(let area) where phase == .results: area.theme
        case .overview, .area: phase == .done ? .green : .violet
        }
    }
}
