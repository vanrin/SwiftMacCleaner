//
//  SidebarStatus.swift
//  SwiftMacCleaner
//

import Foundation

/// What a sidebar entry says about its part since the last look at it.
nonisolated struct SidebarStatus: Equatable, Sendable {
    /// The figure at the entry's right: a size, a count, "Scanning", "Clean".
    var badge: String?
    /// The same in more words, for the label beside a rail entry, where a bare count would not explain itself.
    var detail: String?
    /// The last look left something to do there. The rail, which has no room for the figure, marks it with a dot.
    var hasFindings = false

    /// What the rail's label says after the entry's name.
    var hint: String? { detail ?? badge }
}

extension AppModel {
    /// What the sidebar says about a part.
    func sidebarStatus(of item: SidebarItem) -> SidebarStatus {
        switch item {
        case .overview:
            // What the clean-ups have found between them, while the overview has a scan to show.
            guard overviewPhase != .home, foundSize > 0 else { return SidebarStatus() }
            return SidebarStatus(badge: ByteFormat.string(foundSize), hasFindings: overviewPhase != .scanning)
        case .group(let group):
            let cleanUp = cleanUp(group)
            switch cleanUp.phase {
            case .home:
                return SidebarStatus()
            case .scanning:
                return SidebarStatus(badge: "Scanning")
            case .results, .cleaning, .done:
                let found = cleanUp.foundSize
                return found > 0 ? SidebarStatus(badge: ByteFormat.string(found), hasFindings: true) : SidebarStatus(badge: "Clean")
            }
        case .performance:
            switch performance.phase {
            case .idle:
                return SidebarStatus()
            case .scanning:
                return SidebarStatus(badge: "Scanning")
            case .summary, .managing, .running, .done:
                let count = performance.recommended.count
                return count > 0 ? SidebarStatus(badge: "\(count) to run", hasFindings: true) : SidebarStatus(badge: "Fine")
            }
        case .apps:
            switch apps.phase {
            case .idle:
                return SidebarStatus()
            case .scanning:
                return SidebarStatus(badge: "Scanning")
            case .summary, .managing, .removing, .done:
                let count = apps.apps.count
                let updates = apps.updates.count
                var detail = "\(count) \(count == 1 ? "app" : "apps")"
                if updates > 0 { detail += " · \(updates) \(updates == 1 ? "update" : "updates")" }
                return SidebarStatus(badge: count.formatted(), detail: detail, hasFindings: updates > 0)
            }
        case .space:
            return SidebarStatus()
        }
    }
}
