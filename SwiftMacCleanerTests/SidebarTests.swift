//
//  SidebarTests.swift
//  SwiftMacCleanerTests
//
//  What the sidebar says about each part, and that folding it down is remembered.
//

import Foundation
import Testing
@testable import SwiftMacCleaner

@MainActor
struct SidebarTests {
    private func temporaryHome() throws -> URL {
        let home = FileManager.default.temporaryDirectory.appending(path: "mdc-sidebar-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        return home
    }

    private func finding(id: String, area: Area, size: Int64) -> Finding {
        Finding(id: id, area: area, aftermath: .rebuilds, title: id, summary: "", explanation: "", method: .delete, actionTarget: "",
                items: [FindingItem(id: "\(id)/1", title: "", detail: "", size: size)])
    }

    @Test func anEntrySaysNothingBeforeItsPartIsLookedAt() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let model = AppModel(home: home)
        for item in [SidebarItem.overview, .space, .duplicates] + SidebarItem.parts {
            #expect(model.sidebarStatus(of: item) == SidebarStatus())
        }
    }

    @Test func duplicatesSaysWhatKeepingOneCopyOfEachGivesBack() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let model = AppModel(home: home)
        model.duplicates.showDemo("results")
        let status = model.sidebarStatus(of: .duplicates)
        #expect(status.badge == ByteFormat.string(model.duplicates.reclaimable))
        #expect(status.hint?.hasPrefix("8 groups of identical files") == true)
        #expect(status.hasFindings)
        // The overview's scan leaves it alone, so it is none of the overview's parts.
        #expect(!SidebarItem.parts.contains(.duplicates))
        #expect(!model.isScanning(.duplicates) && !model.hasResults(.duplicates) && !model.hasWork(.duplicates))
    }

    @Test func aCleanUpSaysWhatItFoundAndTheRailMarksIt() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let model = AppModel(home: home)

        model.cleanUp(.system).show(findings: [finding(id: "logs", area: .cachesLogs, size: 2_000_000_000)])
        let found = model.sidebarStatus(of: .group(.system))
        #expect(found.badge == ByteFormat.string(2_000_000_000))
        #expect(found.hint == found.badge)
        #expect(found.hasFindings)

        // A scan that found nothing says so, and leaves the rail's glyph without a dot.
        model.cleanUp(.largeFiles).show(findings: [])
        #expect(model.sidebarStatus(of: .group(.largeFiles)) == SidebarStatus(badge: "Clean"))
        // The clean-up nobody has looked at stays silent.
        #expect(model.sidebarStatus(of: .group(.developer)) == SidebarStatus())
    }

    @Test func applicationsSpellsItsCountOutForTheRail() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let model = AppModel(home: home)
        model.apps.showDemo("summary")
        let status = model.sidebarStatus(of: .apps)
        let count = model.apps.apps.count
        let updates = model.apps.updates.count
        #expect(status.badge == count.formatted())
        // A bare count beside a name would not explain itself, so the rail's label has the words.
        #expect(status.hint?.hasPrefix("\(count) app") == true)
        #expect(status.hint?.contains("update") == (updates > 0))
        #expect(status.hasFindings == (updates > 0))
    }

    @Test func startingOverPutsAPartBackToSayingNothing() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let model = AppModel(home: home)
        model.cleanUp(.system).show(findings: [finding(id: "logs", area: .cachesLogs, size: 2_000_000_000)])
        model.apps.showDemo("summary")
        model.performance.showDemo("summary")
        model.protection.showDemo("results")
        let parts: [SidebarItem] = [.group(.system), .apps, .performance, .protection]
        for part in parts { #expect(model.hasResults(part)) }

        // Starting over on the overview takes it back to its opening screen and leaves each part what it found.
        model.cleanSmart()
        #expect(model.overviewPhase == .results)
        model.startOver()
        #expect(model.overviewPhase == .home)
        #expect(!model.showingOverviewReview)
        #expect(model.sidebarStatus(of: .overview) == SidebarStatus())
        for part in parts { #expect(model.hasResults(part)) }

        // Starting over in a part forgets its scan: the opening screen is back and the entry falls silent.
        model.cleanUp(.system).reset()
        model.apps.reset()
        model.performance.reset()
        model.protection.reset()
        for part in parts {
            #expect(!model.hasResults(part))
            #expect(model.sidebarStatus(of: part) == SidebarStatus())
        }
        #expect(model.cleanUp(.system).phase == .home && model.cleanUp(.system).findings.isEmpty)
        #expect(model.apps.phase == .idle && model.performance.phase == .idle)
        #expect(model.protection.phase == .idle && model.protection.findings.isEmpty)
    }

    @Test func foldingTheSidebarIsRemembered() throws {
        let name = "SidebarTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        #expect(!settings.isSidebarCollapsed)
        settings.toggleSidebar()
        #expect(settings.isSidebarCollapsed)
        #expect(AppSettings(defaults: defaults).isSidebarCollapsed)
        settings.toggleSidebar()
        #expect(!AppSettings(defaults: defaults).isSidebarCollapsed)
    }
}
