//
//  SmartSelectionTests.swift
//  SwiftMacCleanerTests
//
//  What a scan ticks by itself, the three ways to set every tick at once, and the clean nobody confirms.
//

import Foundation
import SwiftUI
import Testing
@testable import SwiftMacCleaner

/// A throwaway folder that stands in for a home directory, with a store of its own for settings.
private struct Sandbox {
    let root: URL
    let defaults = MemoryDefaults()

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "mdc-smart-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    @MainActor
    func settings() -> AppSettings { AppSettings(defaults: defaults) }

    @discardableResult
    func file(_ path: String) throws -> URL {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 7, count: 16).write(to: url)
        return url
    }
}

private func item(_ id: String, _ size: Int64, paths: [URL] = [], preselected: Bool? = nil) -> FindingItem {
    FindingItem(id: id, title: id, detail: "", size: size, paths: paths, preselected: preselected)
}

private func finding(_ id: String, area: Area, aftermath: Aftermath = .rebuilds, method: CleanMethod = .delete,
                     items: [FindingItem]) -> Finding {
    Finding(id: id, area: area, aftermath: aftermath, title: id, summary: "", explanation: "", method: method,
            actionTarget: "", items: items)
}

struct SmartKindTests {
    /// The whole rule, walked over one of everything the scanners make.
    @Test func everyFindingHasItsPlaceOrNone() {
        let findings = DemoData.findings()
        let kinds = Dictionary(uniqueKeysWithValues: findings.map { ($0.id, $0.smart) })
        #expect(kinds["trash.items"] == .trash)
        #expect(kinds[SystemLogs.findingID] == .systemLogs)
        #expect(kinds["caches.apps"] == .appJunk)
        #expect(kinds["projects.stale"] == .staleProjects)
        #expect(kinds["xcode.derivedData"] == .buildOutput)
        #expect(kinds["packages.caches"] == .buildOutput)
        #expect(kinds["xcode.simulators"] == .unused)
        #expect(kinds["toolchains.unused"] == .unused)
        #expect(kinds["ides.oldVersions"] == .unused)
        for finding in findings {
            switch finding.aftermath {
            case .rebuilds:
                #expect(finding.smart != nil, "\(finding.id) rebuilds itself and belongs to no kind")
            case .irreplaceable:
                #expect(finding.smart == nil, "\(finding.id) cannot be recreated and must never be ticked for the user")
            case .discarded:
                #expect(finding.smart == .trash)
            case .downloadsAgain:
                #expect(finding.smart == nil || finding.smart == .unused, "\(finding.id)")
            }
        }
        // Backups, archives, snapshots, models, disk images and the user's own files: no kind at all.
        let never = ["snapshots.backups", "snapshots.local", "xcode.archives", "xcode.oldXcodes", "models.downloads",
                     "containers.docker", "largeFiles.downloads", "android.emulators"]
        let present = never.filter { kinds[$0] != nil }
        #expect(present == never)
        for finding in findings where never.contains(finding.id) {
            #expect(finding.smart == nil, "\(finding.id)")
        }
    }

    /// The figures on the design canvas, which the demo screens show.
    @Test func theStandardSelectionIsTheOneThatWasDrawn() {
        let findings = DemoData.findings().filter(\.area.isCleanUp)
        let found = findings.reduce(Int64(0)) { $0 + $1.size }
        let smart = findings.smartSelection(SmartKind.standard).reduce(Int64(0)) { $0 + $1.size }
        #expect(ByteFormat.string(found) == "188.1 GB")
        #expect(ByteFormat.string(smart) == "72.5 GB")
    }

    @Test func aKindSwitchedOffIsLeftOutAndOneSwitchedOnComesIn() {
        let findings = [
            finding("caches.apps", area: .cachesLogs, items: [item("c/1", 50), item("c/kept", 5, preselected: false)]),
            finding("trash.items", area: .trash, aftermath: .discarded, items: [item("t/1", 20)]),
            finding("xcode.simulators", area: .xcode, aftermath: .downloadsAgain, method: .command, items: [item("x/sim", 40)]),
            finding("snapshots.backups", area: .snapshots, aftermath: .irreplaceable, method: .trash, items: [item("b/1", 30)]),
        ]
        func ticked(_ kinds: Set<SmartKind>) -> Set<String> { Set(findings.smartSelection(kinds).map(\.id)) }
        #expect(SmartKind.standard == [.appJunk, .systemLogs, .trash, .buildOutput, .staleProjects])
        #expect(ticked(SmartKind.standard) == ["c/1", "t/1"])
        #expect(ticked(SmartKind.standard.subtracting([.trash])) == ["c/1"])
        #expect(ticked(SmartKind.standard.union([.unused])) == ["c/1", "t/1", "x/sim"])
        // With every switch on, what a scanner keeps by default and what cannot be recreated still stay out.
        #expect(ticked(Set(SmartKind.allCases)) == ["c/1", "t/1", "x/sim"])
        #expect(ticked([]).isEmpty)
    }

    @MainActor
    @Test func theSwitchesAreRemembered() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let settings = sandbox.settings()
        #expect(settings.smartKinds == SmartKind.standard)
        #expect(!settings.weeklyCheckCleans)

        settings.smartKinds.remove(.trash)
        settings.smartKinds.insert(.unused)
        settings.weeklyCheckCleans = true
        let reopened = sandbox.settings()
        #expect(reopened.smartKinds == [.appJunk, .systemLogs, .buildOutput, .staleProjects, .unused])
        #expect(reopened.weeklyCheckCleans)

        // Every switch off is a choice too, and is not taken for nothing having been stored.
        settings.smartKinds = []
        #expect(sandbox.settings().smartKinds.isEmpty)
        // A name a later version no longer knows is passed over.
        sandbox.defaults.set(["trash", "no-such-kind"], forKey: "smartKinds")
        #expect(sandbox.settings().smartKinds == [.trash])
    }
}

@MainActor
struct SelectionPresetTests {
    @Test func aPresetSetsEveryTickOfEveryCleanUpAndRunFollows() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let model = AppModel(home: sandbox.root, settings: sandbox.settings())
        let system = model.cleanUp(.system)
        let large = model.cleanUp(.largeFiles)
        // Each item names something on disk, as a scanned one does: the figures count what a clean would remove.
        func at(_ path: String) -> [URL] { [sandbox.root.appending(path: path)] }
        system.show(findings: [
            finding("caches.apps", area: .cachesLogs, items: [item("c/1", 50, paths: at("Library/Caches/x"))]),
            finding("trash.items", area: .trash, aftermath: .discarded, items: [item("t/1", 20, paths: at(".Trash/x"))]),
            finding("snapshots.backups", area: .snapshots, aftermath: .irreplaceable, method: .trash,
                    items: [item("b/1", 30, paths: at("Library/Application Support/MobileSync/Backup/x"))]),
        ])
        large.show(findings: [
            finding("largeFiles.downloads", area: .largeFiles, aftermath: .irreplaceable, method: .trash,
                    items: [item("l/1", 5, paths: at("Downloads/x.zip"))]),
        ])
        model.select(.smart)
        #expect(model.preset == .smart)
        #expect(system.selection == ["c/1", "t/1"])
        #expect(large.selection.isEmpty)
        #expect(model.included == [.group(.system)])
        #expect(model.runSize == 70)

        model.select(.everything)
        #expect(model.preset == .everything)
        #expect(system.selection == ["c/1", "t/1", "b/1"])
        #expect(large.selection == ["l/1"])
        #expect(model.included == [.group(.system), .group(.largeFiles)])
        #expect(model.runSize == 105)
        #expect(model.selectedSize == model.foundSize)

        model.select(.nothing)
        #expect(system.selection.isEmpty)
        #expect(model.included.isEmpty)
        #expect(model.runSize == 0)
        // Nothing ticked among the large files is what Smart stands for there, so the two clean-ups differ.
        #expect(system.preset() == .nothing)
        #expect(large.preset() == .smart)
        #expect(model.preset == nil)

        // The tick on a part that is not a clean-up is not the presets' to change.
        model.included = [.performance]
        model.select(.smart)
        #expect(model.included == [.performance, .group(.system)])
    }

    @Test func aSwitchInSettingsMovesTheTicksThatWereSmartAndLeavesTheRest() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let model = AppModel(home: sandbox.root, settings: sandbox.settings())
        let system = model.cleanUp(.system)
        let developer = model.cleanUp(.developer)
        system.show(findings: [
            finding("caches.apps", area: .cachesLogs, items: [item("c/1", 50)]),
            finding("trash.items", area: .trash, aftermath: .discarded, items: [item("t/1", 20)]),
        ])
        let simulators = finding("xcode.simulators", area: .xcode, aftermath: .downloadsAgain, method: .command, items: [item("x/sim", 40)])
        let archives = finding("xcode.archives", area: .xcode, aftermath: .irreplaceable, method: .trash, items: [item("x/arc", 10)])
        developer.show(findings: [finding("xcode.derivedData", area: .xcode, items: [item("x/1", 30)]), simulators, archives])
        #expect(system.selection == ["c/1", "t/1"])
        #expect(developer.selection == ["x/1"])

        model.setSmart(.trash, isOn: false)
        #expect(system.selection == ["c/1"])
        #expect(system.preset() == .smart)
        model.setSmart(.unused, isOn: true)
        #expect(developer.selection == ["x/1", "x/sim"])
        #expect(model.smartSize == 120)

        // Ticks set by hand are the user's, and a switch does not undo them.
        developer.binding(for: archives.items[0]).wrappedValue = true
        #expect(developer.preset() == .everything)
        model.setSmart(.unused, isOn: false)
        #expect(developer.selection == ["x/1", "x/sim", "x/arc"])
        #expect(developer.preset() == .everything)
        model.setSmart(.trash, isOn: true)
        #expect(system.selection == ["c/1", "t/1"])
    }
}

@MainActor
struct CleanFateTests {
    @Test func theConfirmationGroupsByWhatBecomesOfEachGroup() {
        let somewhere = [URL(fileURLWithPath: "/Users/someone/x")]
        let findings = [
            finding("caches", area: .cachesLogs, items: [item("c/1", 50, paths: somewhere)]),
            finding("trash.items", area: .trash, aftermath: .discarded, items: [item("t/1", 20, paths: somewhere)]),
            finding("simulators", area: .xcode, aftermath: .downloadsAgain, method: .command,
                    items: [FindingItem(id: "x/1", title: "", detail: "", size: 40, command: ["/usr/bin/true"])]),
            finding("snapshots", area: .snapshots, aftermath: .irreplaceable, method: .adminCommand,
                    items: [FindingItem(id: "s/1", title: "", detail: "", size: 0, command: ["/usr/bin/true"], sizeUnknown: true)]),
            finding("backups", area: .snapshots, aftermath: .irreplaceable, method: .trash, items: [item("b/1", 30, paths: somewhere)]),
        ]
        let plan = CleanPlan.make(findings: findings, selection: ["c/1", "t/1", "x/1", "s/1", "b/1"])
        #expect(plan.steps.map(\.fate) == [.deleted, .trashEmptied, .run, .run, .trashed])
        #expect(plan.trashedSize == 30)
        #expect(plan.finalSize == 110)
        #expect(plan.passwordPromptCount == 1)
        // The order the confirmation lists them in: what is final first, what can be put back last.
        #expect(CleanFate.allCases == [.deleted, .trashEmptied, .deletedAsRoot, .run, .trashed])
        #expect(CleanMethod.trash.isFinal == false)
        let final = [CleanMethod.delete, .command, .adminCommand, .adminDelete].filter { $0.isFinal }
        #expect(final.count == 4)

        let twoPrompts = CleanPlan(steps: plan.steps + [
            CleanStep(id: "junk", title: "", aftermath: .rebuilds, method: .adminDelete, summary: "", size: 0, operations: []),
        ])
        #expect(twoPrompts.passwordPromptTimes == "twice")
        #expect(twoPrompts.withoutPasswordSteps.steps.map(\.id) == ["caches", "trash.items", "simulators", "backups"])
    }

    /// The clean after the weekly check: nobody confirmed it, so it never reaches a password prompt.
    @Test func aCleanNobodyWatchesLeavesOutWhatNeedsAPassword() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let log = try sandbox.file("Library/Logs/app/out.log").deletingLastPathComponent()
        let system = AppModel(home: sandbox.root, settings: sandbox.settings()).cleanUp(.system)
        let target = SystemLogs.Target(root: URL(fileURLWithPath: "/Library/Logs", isDirectory: true), folder: "NoSuchFolder")
        let junk = Finding(id: SystemLogs.findingID, area: .cachesLogs, aftermath: .rebuilds, title: "System logs",
                           summary: "", explanation: "", method: .adminDelete, actionTarget: "",
                           items: [FindingItem(id: "j/1", title: "", detail: "", size: 100, paths: [target.url],
                                               systemTarget: target)])
        system.show(findings: [finding("caches.logs", area: .cachesLogs, items: [item("c/1", 10, paths: [log])]), junk])
        #expect(system.selection == ["c/1", "j/1"])
        #expect(system.plan.passwordPromptCount == 1)

        let outcome = try #require(await system.runClean(area: nil, unattended: true))
        #expect(outcome.steps.map(\.id) == ["caches.logs"])
        #expect(!Files.exists(log))
        // What needed the password is still there, still ticked, for the next clean somebody confirms.
        #expect(system.findings.map(\.id) == [SystemLogs.findingID])
        #expect(system.selection == ["j/1"])
    }
}
