//
//  GlyphSelection.swift
//  SwiftMacCleaner
//

import SwiftUI

// The glyphs are custom symbols in the asset catalog, under Glyphs. `Tools/make-glyphs.swift` draws them.

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
    /// The glyph that pictures this group.
    var glyph: ImageResource {
        switch self {
        case .system: .glyphSystem
        case .developer: .glyphDeveloper
        case .largeFiles: .glyphLargeFiles
        }
    }
}

extension SidebarItem {
    /// The glyph of this entry in the sidebar and on its tile.
    var glyph: ImageResource {
        switch self {
        case .overview: .glyphOverview
        case .group(let group): group.glyph
        case .space: .glyphSpace
        case .duplicates: .glyphDuplicates
        case .apps: .glyphApps
        case .performance: .glyphPerformance
        }
    }
}
