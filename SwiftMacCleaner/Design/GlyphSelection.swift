//
//  GlyphSelection.swift
//  SwiftMacCleaner
//

import SwiftUI

// The glyphs are custom symbols in the asset catalog, under Glyphs. `Tools/make-glyphs.swift` draws them,
// and with them the icon of each part of the app, which `ModuleIcon` shows as an object.

extension Area {
    /// The glyph that pictures this area.
    var glyph: ImageResource {
        switch self {
        case .xcode: .glyphXcode
        case .projects: .glyphProjects
        case .android: .glyphAndroid
        case .containers: .glyphContainers
        case .packageCaches: .glyphPackageCaches
        case .toolchains: .glyphToolchains
        case .ides: .glyphIdes
        case .models: .glyphModels
        case .cachesLogs: .glyphCachesLogs
        case .trash: .glyphTrash
        case .snapshots: .glyphSnapshots
        case .largeFiles: .glyphLargeFiles
        case .leftovers: .glyphLeftovers
        case .installers: .glyphInstallers
        }
    }
}

extension AreaGroup {
    /// The icon of this clean-up.
    var icon: ImageResource {
        switch self {
        case .system: .moduleSystem
        case .developer: .moduleDeveloper
        case .largeFiles: .moduleLargeFiles
        }
    }
}

extension SidebarItem {
    /// The icon of this entry in the sidebar, on its tile and on its own screens.
    var icon: ImageResource {
        switch self {
        case .overview: .moduleOverview
        case .group(let group): group.icon
        case .space: .moduleSpace
        case .duplicates: .moduleDuplicates
        case .apps: .moduleApps
        case .performance: .modulePerformance
        case .protection: .moduleProtection
        case .activity: .moduleActivity
        }
    }
}

extension VitalKind {
    /// The glyph beside this reading's name in its details.
    var glyph: ImageResource {
        switch self {
        case .cpu: .glyphCpu
        case .memory: .glyphMemory
        case .battery: .glyphBattery
        }
    }
}
