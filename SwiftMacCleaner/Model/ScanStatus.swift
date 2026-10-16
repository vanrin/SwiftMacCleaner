//
//  ScanStatus.swift
//  SwiftMacCleaner
//

import Foundation

extension CleanUpModel {
    /// The areas being measured right now, and how many are done.
    var scanDetail: String {
        let areas = scannedAreas
        let progress = "\(finishedAreaCount) of \(areas.count) areas done"
        let current = areas.filter { areaState(for: $0) == .scanning }.map(\.title)
        guard !current.isEmpty else { return progress }
        return "\(current.formatted(.list(type: .and, width: .narrow))) · \(progress)"
    }
}

extension AppModel {
    /// What a part's scan is doing, in the words of its own scanning screen, which the overview's
    /// card for it repeats. Empty for an entry the overview's scan leaves out.
    func scanTitle(of part: SidebarItem) -> String {
        switch part {
        case .group(let group): "Scanning \(group.scope)"
        case .apps: "Looking at your apps"
        case .performance: "Examining your Mac"
        case .protection: "Checking your Mac's protection"
        case .overview, .space, .duplicates, .activity: ""
        }
    }

    /// The one line under that: what the scan is on right now.
    func scanDetail(of part: SidebarItem) -> String {
        switch part {
        case .group(let group): cleanUp(group).scanDetail
        case .apps: apps.progress.detail
        case .performance: performance.progress
        case .protection: "Reading how its defences are set"
        case .overview, .space, .duplicates, .activity: ""
        }
    }

    /// The part of the overview's scan that stands large on screen: the first, in the order of the
    /// sidebar, that is still at work. The parts are scanned side by side, so others may be at work too.
    var featuredScan: SidebarItem? {
        overviewParts.first(where: isScanning)
    }
}
