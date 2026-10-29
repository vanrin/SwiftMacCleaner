//
//  DeveloperCachesTests.swift
//  SwiftMacCleanerTests
//
//  Device support left by system updates, caches inside simulators, emulator snapshots, older NDKs,
//  Flutter's old build caches and the extension copies editors have replaced.
//

import Foundation
import Testing
@testable import SwiftMacCleaner

/// A throwaway folder that stands in for a home directory.
private struct Sandbox {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "mdc-devcaches-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    @discardableResult
    func file(_ path: String, bytes: Int = 16, age days: Double = 0) throws -> URL {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 7, count: bytes).write(to: url)
        try setAge(days, of: url)
        return url
    }

    func setAge(_ days: Double, of url: URL) throws {
        let date = Date().addingTimeInterval(-days * 86_400)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }

    func url(_ path: String) -> URL { root.appending(path: path) }
}

/// Paths as the file system names them, so /var and /private/var, or a trailing slash, do not matter.
private func resolved(_ urls: [URL]) -> Set<String> {
    Set(urls.map { $0.resolvingSymlinksInPath().path })
}

struct DeviceSupportTests {
    @Test func keepsOnlyTheNewestVersionForEachModel() {
        let choices = XcodeScanner.deviceSupportChoices([
            "iPhone17,2 27.0 (24A437)", "iPhone17,2 27.0.1 (24A446)", "iPhone17,2 26.4 (23E244)",
            "iPad16,3 26.4 (23E244)",
        ])
        #expect(choices["iPhone17,2 27.0.1 (24A446)"] == .newestForModel("iPhone17,2"))
        #expect(choices["iPhone17,2 27.0 (24A437)"] == .replaced(model: "iPhone17,2", newer: "27.0.1"))
        #expect(choices["iPhone17,2 26.4 (23E244)"] == .replaced(model: "iPhone17,2", newer: "27.0.1"))
        // Another model keeps its own newest, even when it is older than the phone's.
        #expect(choices["iPad16,3 26.4 (23E244)"] == .newestForModel("iPad16,3"))
    }

    @Test func foldersWithoutAModelKeepTheWholeNewestMajor() {
        let choices = XcodeScanner.deviceSupportChoices(["17.5 (21F79)", "17.6 (21G80)", "16.4 (20E247) arm64e", "notes"])
        #expect(choices["17.5 (21F79)"] == .newestMajor)
        #expect(choices["17.6 (21G80)"] == .newestMajor)
        #expect(choices["16.4 (20E247) arm64e"] == .older)
        #expect(choices["notes"] == nil)
        #expect(XcodeScanner.SupportChoice.newestMajor.isKept)
        #expect(!XcodeScanner.SupportChoice.replaced(model: "x", newer: "1").isKept)
    }

    @Test func readsTheModelAndTheWholeVersion() throws {
        let parsed = try #require(XcodeScanner.deviceSupportVersion(in: "Watch7,1 11.0.1 (22R123)"))
        #expect(parsed.model == "Watch7,1")
        #expect(parsed.version == [11, 0, 1])
        #expect(XcodeScanner.deviceSupportVersion(in: "17.5 (21F79)")?.model == nil)
    }
}

struct SimulatorCacheTests {
    @Test func offersTheCachesOfShutDownDevicesTheScanKeeps() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let devices = "Library/Developer/CoreSimulator/Devices"
        for udid in ["KEPT", "BOOTED", "OFFERED", "GONE"] {
            try sandbox.file("\(devices)/\(udid)/data/Library/Caches/com.apple.nsurlsessiond/blob")
            try sandbox.file("\(devices)/\(udid)/data/Library/Caches/GeoServices/tiles")
            try sandbox.file("\(devices)/\(udid)/data/Containers/Data/Application/APP/Documents/notes")
        }
        let json = """
        {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-27-0": [
          {"udid": "KEPT", "name": "iPhone 18", "state": "Shutdown", "isAvailable": true},
          {"udid": "BOOTED", "name": "iPhone 18 Pro", "state": "Booted", "isAvailable": true},
          {"udid": "OFFERED", "name": "iPad", "state": "Shutdown", "isAvailable": true},
          {"udid": "GONE", "name": "Old", "state": "Shutdown", "isAvailable": false}
        ]}}
        """
        let groups = XcodeScanner.simulatorCacheGroups(fromJSON: json, offered: ["xcode.simulators/device/OFFERED"],
                                                       context: ScanContext(home: sandbox.root))
        #expect(groups.map(\.id) == ["KEPT"])
        let group = try #require(groups.first)
        #expect(group.title == "iPhone 18 (iOS 27.0)")
        #expect(resolved(group.paths) == resolved([sandbox.url("\(devices)/KEPT/data/Library/Caches/com.apple.nsurlsessiond"),
                                     sandbox.url("\(devices)/KEPT/data/Library/Caches/GeoServices")]))
        let safety = SafetyGuard(root: sandbox.root)
        #expect(group.paths.allSatisfy(safety.allows))
    }
}

struct EmulatorSnapshotTests {
    @Test func offersQuickBootSnapshotsAndKeepsThisWeeksUnticked() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let avd = ".android/avd"
        for (name, age) in [("Recent", 1.0), ("LastMonth", 20.0), ("Stale", 200.0)] {
            try sandbox.file("\(avd)/\(name).avd/snapshots/default_boot/ram.bin")
            try sandbox.file("\(avd)/\(name).avd/snapshots/before_upgrade/ram.bin")
            try sandbox.file("\(avd)/\(name).avd/userdata-qemu.img.qcow2")
            try sandbox.setAge(age, of: sandbox.url("\(avd)/\(name).avd"))
        }

        let finding = try #require(await AndroidScanner.snapshots(ScanContext(home: sandbox.root), minimumSize: 1))
        #expect(finding.aftermath == .rebuilds)
        #expect(finding.smart == .buildOutput)
        #expect(resolved(finding.items.flatMap(\.paths)) == resolved([
            sandbox.url("\(avd)/Recent.avd/snapshots/default_boot"), sandbox.url("\(avd)/LastMonth.avd/snapshots/default_boot"),
        ]), "A named snapshot is the user's own, and a stale emulator is offered whole elsewhere")
        #expect(finding.items.first { $0.title == "Recent emulator" }?.preselected == false)
        #expect(finding.items.first { $0.title == "LastMonth emulator" }?.preselected == nil)
    }
}

struct NDKTests {
    @Test func offersOlderNDKsUntickedAndKeepsTheNewest() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        for version in ["27.0.12077973", "28.2.13676358", "28.0.13004108"] {
            try sandbox.file("Library/Android/sdk/ndk/\(version)/source.properties")
        }
        let finding = try #require(await AndroidScanner.olderNDKs(ScanContext(home: sandbox.root), minimumSize: 1))
        #expect(finding.method == .trash)
        #expect(Set(finding.items.map(\.title)) == ["NDK 27.0.12077973", "NDK 28.0.13004108"])
        #expect(finding.items.allSatisfy { $0.preselected == false })
        #expect(finding.summary.contains("28.2.13676358"))
    }
}

struct FlutterBuildCacheTests {
    @Test func offersIdleBuildCachesInAnActiveProjectAndKeepsTheNewest() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let app = "Projects/app"
        try FileManager.default.createDirectory(at: sandbox.url("\(app)/.git"), withIntermediateDirectories: true)
        try sandbox.file("\(app)/pubspec.yaml")
        try sandbox.file("\(app)/lib/main.dart")
        for (hash, age) in [("old1", 40.0), ("old2", 12.0), ("current", 1.0)] {
            let file = try sandbox.file("\(app)/.dart_tool/flutter_build/\(hash)/app.dill", age: age)
            try sandbox.setAge(age, of: file.deletingLastPathComponent())
        }
        for (hash, age) in [("aaa", 30.0), ("bbb", 9.0)] {
            try sandbox.file("\(app)/build/\(hash).cache.dill.track.dill", age: age)
        }
        try sandbox.file("\(app)/build/app/outputs/app.apk")

        let context = ScanContext(home: sandbox.root, projectRoots: [sandbox.url("Projects")])
        var projects: [URL: ProjectScanner.Project] = [:]
        var cloud: [URL] = []
        ProjectScanner.walk(sandbox.url("Projects"), depth: 0, owner: nil, projects: &projects, cloud: &cloud, context: context)
        let finding = try #require(await ProjectScanner.flutterBuildCaches(in: Array(projects.values), context: context, minimumSize: 1))
        #expect(finding.smart == .buildOutput, "Build caches are build output, not a stale project's dependencies")
        #expect(resolved(finding.items.flatMap(\.paths)) == resolved([
            sandbox.url("\(app)/.dart_tool/flutter_build/old1"), sandbox.url("\(app)/.dart_tool/flutter_build/old2"),
            // bbb is older than a week too, but it is the newest kernel, so it stays.
            sandbox.url("\(app)/build/aaa.cache.dill.track.dill"),
        ]))
    }

    @Test func theNewestCacheStaysEvenWhenEveryOneIsIdle() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        var entries: [URL] = []
        for (hash, age) in [("a", 50.0), ("b", 30.0)] {
            let file = try sandbox.file("flutter_build/\(hash)/app.dill", age: age)
            try sandbox.setAge(age, of: file.deletingLastPathComponent())
            entries.append(file.deletingLastPathComponent())
        }
        #expect(resolved(ProjectScanner.idleEntries(entries, context: ScanContext(home: sandbox.root))) == resolved([sandbox.url("flutter_build/a")]))
    }
}

struct ReplacedExtensionTests {
    @Test func offersWhatTheEditorMarkedObsoleteAndNothingElse() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let root = ".vscode/extensions"
        try sandbox.file("\(root)/openai.chatgpt-26.1007.21434-darwin-arm64/package.json")
        try sandbox.file("\(root)/openai.chatgpt-26.1021.22027-darwin-arm64/package.json")
        try sandbox.file("\(root)/ms-python.python-2026.4.0/package.json")
        let marked = ["openai.chatgpt-26.1007.21434-darwin-arm64": true, "ms-python.python-2026.4.0": false,
                      "../../Documents": true, "missing.extension-1.0.0": true]
        try JSONSerialization.data(withJSONObject: marked).write(to: sandbox.url("\(root)/.obsolete"))

        let finding = try #require(await IDEScanner.obsoleteExtensions(ScanContext(home: sandbox.root), minimumSize: 1))
        #expect(resolved(finding.items.flatMap(\.paths)) == resolved([sandbox.url("\(root)/openai.chatgpt-26.1007.21434-darwin-arm64")]))
        let item = try #require(finding.items.first)
        #expect(item.title == "openai.chatgpt 26.1007.21434 in VS Code")
        #expect(item.keptBy == "com.microsoft.VSCode")
    }

    @Test func namesAnExtensionByItsIDAndVersion() {
        #expect(IDEScanner.extensionTitle("ms-python.vscode-pylance-2026.4.1") == "ms-python.vscode-pylance 2026.4.1")
        #expect(IDEScanner.extensionTitle("hediet.vscode-drawio-1.17.0") == "hediet.vscode-drawio 1.17.0")
        #expect(IDEScanner.extensionTitle("plain") == "plain")
    }
}
