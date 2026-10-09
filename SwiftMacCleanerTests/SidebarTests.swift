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
        Finding(id: id, area: area, tier: .safe, title: id, summary: "", explanation: "", method: .delete, actionTarget: "",
                items: [FindingItem(id: "\(id)/1", title: "", detail: "", size: size)])
    }

    @Test func anEntrySaysNothingBeforeItsPartIsLookedAt() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let model = AppModel(home: home)
        for item in [SidebarItem.overview, .space] + SidebarItem.parts {
            #expect(model.sidebarStatus(of: item) == SidebarStatus())
        }
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
        model.cleanUp(.downloads).show(findings: [])
        #expect(model.sidebarStatus(of: .group(.downloads)) == SidebarStatus(badge: "Clean"))
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
