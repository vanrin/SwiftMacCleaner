//
//  OverviewFigure.swift
//  SwiftMacCleaner
//

import Foundation

/// What the overview says about one of its parts: the figure that matters, the line under it, and
/// for a clean-up how much of what was found is ticked.
nonisolated struct OverviewFigure: Equatable, Sendable {
    var value: String
    var caption: String
    var selection: String?
    var isSelected = false

    init(_ value: String, _ caption: String, selection: String? = nil, isSelected: Bool = false) {
        self.value = value
        self.caption = caption
        self.selection = selection
        self.isSelected = isSelected
    }
}

extension AppModel {
    /// The large figure for a part and the lines under it, on its tile and on its card while the
    /// overview scans. A clean-up shows everything it found, and then what Run would take of it; the
    /// other parts say what Run would do in their own terms.
    func overviewFigure(of part: SidebarItem) -> OverviewFigure {
        if isScanning(part) { return OverviewFigure("Scanning", "still looking") }
        guard hasResults(part) else { return OverviewFigure("Not scanned", "open it to scan on its own") }
        switch part {
        case .group(let group):
            let cleanUp = cleanUp(group)
            let found = cleanUp.foundSize
            if cleanUp.phase == .done { return OverviewFigure("Cleaned", found > 0 ? "\(ByteFormat.string(found)) more found, not selected" : "nothing left") }
            if found == 0 { return OverviewFigure("Nothing", "to clean") }
            let selected = cleanUp.selectedSize
            let isSelected = selected > 0 || cleanUp.selectionHasUnknownSize
            return OverviewFigure(ByteFormat.string(found), group.holdsJunk ? "of junk found" : "found",
                                  selection: isSelected ? "\(ByteFormat.string(selected)) selected" : "Nothing selected",
                                  isSelected: isSelected)
        case .performance:
            let count = performance.recommended.count
            if performance.phase == .done { return OverviewFigure("Ran", "the tasks that were due") }
            return count == 0 ? OverviewFigure("Nothing", "to run today") : OverviewFigure("\(count) \(count == 1 ? "task" : "tasks")", "to run")
        case .protection:
            let count = protection.toLookAt.count
            let inPlace = protection.inPlace.count
            return count == 0
                ? OverviewFigure("In place", "\(inPlace) of \(protection.findings.count) defences are on")
                : OverviewFigure("\(count) \(count == 1 ? "setting" : "settings")", "worth a look in System Settings")
        case .apps:
            if !apps.updates.isEmpty {
                let count = apps.updates.count
                return OverviewFigure("\(count) \(count == 1 ? "update" : "updates")", "to install from the store or the app")
            }
            let leftovers = apps.leftoverFileSize + apps.installerSize
            if leftovers > 0 { return OverviewFigure(ByteFormat.string(leftovers), "of leftovers and installers to review") }
            let unused = apps.unusedApps.count
            return unused > 0 ? OverviewFigure("\(unused) unused \(unused == 1 ? "app" : "apps")", "to review") : OverviewFigure("Up to date", "nothing to remove")
        case .overview, .space, .duplicates, .activity:
            return OverviewFigure("", "")
        }
    }
}
