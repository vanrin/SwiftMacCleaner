//
//  StartingOver.swift
//  SwiftMacCleaner
//

import Foundation

extension AppModel {
    /// Whether the overview has a scan to show. That scan is every part's, so while it stands,
    /// starting over in any one of its parts starts all of them over.
    var overviewHoldsScan: Bool {
        overviewPhase == .results || overviewPhase == .done
    }

    /// Whether starting over from this entry takes every part of the overview with it. A part that
    /// was scanned on its own starts over alone, and so do the two the overview's scan leaves out.
    func startsEverythingOver(from item: SidebarItem) -> Bool {
        switch item {
        case .overview: true
        case .group, .apps, .performance, .protection: overviewHoldsScan
        case .space, .duplicates: false
        }
    }

    /// Forgets a scan and goes back to the opening screen: of every part when the scan was the
    /// overview's, of this part alone when it was its own. Whichever entry is open stays open.
    func startOver(from item: SidebarItem) {
        guard !startsEverythingOver(from: item) else { return startOver() }
        switch item {
        case .group(let group): cleanUp(group).reset()
        case .apps: apps.reset()
        case .performance: performance.reset()
        case .protection: protection.reset()
        case .space: space.reset()
        case .duplicates: duplicates.reset()
        case .overview: break
        }
    }

    /// What the question asked before starting over says will be forgotten, and what is left alone.
    func startOverWarning(from item: SidebarItem) -> String {
        let untouched = "Nothing on your Mac is removed or changed."
        if startsEverythingOver(from: item) {
            return item == .overview
                ? "What the scan found in every part, and what you ticked there, is forgotten. \(untouched)"
                : "The overview's scan covers every part, so all of them start over together. What was found in each, and what you ticked there, is forgotten. \(untouched)"
        }
        return switch item {
        case .protection: "What this check found is forgotten. Nothing on your Mac is changed."
        case .space: "What was measured is forgotten, and you choose again what to measure. \(untouched)"
        case .duplicates: "The duplicates this scan found, and what you ticked among them, are forgotten. \(untouched)"
        case .overview, .group, .apps, .performance:
            "What this scan found in \(item.title), and what you ticked there, is forgotten. \(untouched)"
        }
    }
}
