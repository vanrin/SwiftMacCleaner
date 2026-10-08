//
//  DeveloperScannerTests.swift
//  SwiftMacCleanerTests
//

import Foundation
import Testing
@testable import SwiftMacCleaner

/// A throwaway folder that stands in for a home directory.
private struct Sandbox {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "mdc-tests-\(UUID().uuidString)")
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

    func link(_ path: String, to target: String) throws {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: root.appending(path: target))
    }
}

struct OldXcodeTests {
    @Test func offersOtherXcodesAndKeepsTheSelectedOne() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let old = sandbox.root.appending(path: "Applications/Xcode-16.4.app")
        let selected = sandbox.root.appending(path: "Applications/Xcode.app")
        for (bundle, version) in [(old, "16.4"), (selected, "26.0")] {
            try sandbox.file("Applications/\(bundle.lastPathComponent)/Contents/Developer/usr/bin/xcodebuild", bytes: 2_000_000)
            let info: [String: Any] = ["CFBundleShortVersionString": version]
            try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
                .write(to: bundle.appending(path: "Contents/Info.plist"))
        }

        let context = ScanContext(home: sandbox.root)
        let report = await XcodeScanner.oldXcodes(others: [old], selected: selected, context: context, minimumSize: 1_000_000)
        let finding = try #require(report.finding)
        #expect(finding.tier == .careful)
        #expect(finding.method == .trash)
        #expect(finding.items.map(\.title) == ["Xcode 16.4"])
        #expect(finding.items.first?.paths == [old])
        #expect(finding.items.first?.detail.contains("Xcode 26.0") == true)
        #expect(report.protected.map(\.title) == ["Xcode 26.0"])
        #expect(report.protected.first?.rule == .defaultVersion)
    }

    @Test func theSettingSwitchesTheFindingOffThroughTheExcludedList() async {
        let context = ScanContext(home: URL(fileURLWithPath: "/Users/me"), excluded: [XcodeScanner.oldXcodesFindingID])
        let report = await XcodeScanner.oldXcodes(context)
        #expect(report.finding == nil)
        #expect(report.protected.isEmpty)
    }
}

struct SimulatorProtectionTests {
    private let context = ScanContext(home: URL(fileURLWithPath: "/Users/me"), staleDays: 60)

    @Test func aBootedDeviceIsListedAsInUseInsteadOfOffered() {
        let old = ISO8601DateFormatter().string(from: context.now.addingTimeInterval(-200 * 86_400))
        let json = """
        {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-17-0": [
          {"udid": "RUN", "name": "iPhone 14", "state": "Booted", "isAvailable": true, "dataPathSize": 3000000000, "lastUsedAt": "\(old)"},
          {"udid": "OLD", "name": "iPhone 15", "state": "Shutdown", "isAvailable": true, "dataPathSize": 3000000000, "lastUsedAt": "\(old)"}
        ]}}
        """
        let report = XcodeScanner.deviceReport(fromJSON: json, xcrun: "/usr/bin/xcrun", context: context)
        #expect(report.items.map(\.id) == ["xcode.simulators/device/OLD"])
        #expect(report.protected.map(\.title) == ["iPhone 14 (iOS 17.0)"])
        #expect(report.protected.first?.rule == .inUse)
        #expect(report.protected.first?.size == 3_000_000_000)
    }

    @Test func theNewestNeverUsedRuntimeIsKeptOnPurpose() {
        let json = """
        {
          "C": {"identifier": "C", "version": "27.0", "platformIdentifier": "com.apple.platform.iphonesimulator", "sizeBytes": 10000000000, "state": "Ready", "deletable": true}
        }
        """
        let report = XcodeScanner.runtimeReport(fromJSON: json, xcrun: "/usr/bin/xcrun", context: context)
        #expect(report.items.isEmpty)
        #expect(report.protected.map(\.title) == ["iOS 27.0 Simulator runtime"])
        #expect(report.protected.first?.rule == .defaultVersion)
    }
}

struct ProjectCloudTests {
    @Test func aProjectRootInICloudDriveIsProtectedNotWalked() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let cloud = "Library/Mobile Documents/com~apple~CloudDocs/Thesis"
        try sandbox.file("\(cloud)/package.json", age: 200)
        try sandbox.file("\(cloud)/node_modules/pkg/index.js", bytes: 2_000_000, age: 200)
        try sandbox.file("Code/old-app/package.json", age: 200)
        try sandbox.file("Code/old-app/node_modules/pkg/index.js", bytes: 2_000_000, age: 200)
        try sandbox.setAge(200, of: sandbox.root.appending(path: "Code/old-app/node_modules"))

        let context = ScanContext(home: sandbox.root, staleDays: 60, projectRoots: [
            sandbox.root.appending(path: cloud), sandbox.root.appending(path: "Code"),
        ])
        let result = await ProjectScanner.scan(context)
        #expect(result.findings.first?.items.map(\.title) == ["old-app"])
        #expect(result.protected.map(\.title) == ["Thesis"])
        #expect(result.protected.first?.rule == .protectedList)
    }

    @Test func anActiveProjectShowsUpUnderProtected() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.file("Code/fresh-app/package.json")
        try sandbox.file("Code/fresh-app/node_modules/pkg/index.js", bytes: 2_000_000)

        let context = ScanContext(home: sandbox.root, staleDays: 60, projectRoots: [sandbox.root.appending(path: "Code")])
        let result = await ProjectScanner.scan(context)
        #expect(result.findings.isEmpty)
        #expect(result.protected.map(\.title) == ["fresh-app"])
        #expect(result.protected.first?.rule == .recentlyUsed)
        #expect(result.skipReason?.contains("60 days") == true)
    }
}

struct VersionManagerTests {
    @Test func fnmKeepsTheDefaultAndTheNewestNode() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let base = "Library/Application Support/fnm"
        for version in ["v18.19.0", "v20.11.1", "v22.3.0"] {
            try sandbox.file("\(base)/node-versions/\(version)/installation/bin/node", bytes: 21_000_000)
        }
        try sandbox.link("\(base)/aliases/default", to: "\(base)/node-versions/v18.19.0")

        let result = await ToolchainScanner.scan(ScanContext(home: sandbox.root))
        let offered = result.findings.first?.items.map(\.title) ?? []
        #expect(offered == ["Node v20.11.1"])
        let kept = Dictionary(uniqueKeysWithValues: result.protected.map { ($0.title, $0.why) })
        #expect(kept["Node v18.19.0"] == "Your default Node version in fnm")
        #expect(kept["Node v22.3.0"] == "Newest Node version in fnm, kept by default")
    }

    @Test func asdfKeepsWhatToolVersionsPins() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        for version in ["17.0.9", "21.0.4"] {
            try sandbox.file(".asdf/installs/java/\(version)/bin/java", bytes: 21_000_000)
        }
        try "java 17.0.9\nnodejs 20.11.1 # pinned\n".write(to: sandbox.file(".tool-versions"), atomically: true, encoding: .utf8)

        let result = await ToolchainScanner.scan(ScanContext(home: sandbox.root))
        #expect(result.findings.first?.items.map(\.title) == ["Java 21.0.4"])
        #expect(result.protected.map(\.title) == ["Java 17.0.9"])
        #expect(result.protected.first?.rule == .defaultVersion)
    }

    @Test func readsMiseAndVoltaDefaults() throws {
        let config = """
        [settings]
        experimental = true

        [tools]
        node = "20"
        python = ["3.12", "3.11"]
        """
        #expect(ToolchainScanner.miseTools(in: config) == ["node": ["20"], "python": ["3.12", "3.11"]])
        #expect(ToolchainScanner.toolVersions(in: ["java 17.0.9", "nodejs 20.11.1 18.19.0", "# comment"])
                == ["java": ["17.0.9"], "nodejs": ["20.11.1", "18.19.0"]])

        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let platform = try sandbox.file(".volta/tools/user/platform.json")
        try #"{"node":{"runtime":"20.11.1","npm":null},"yarn":null}"#.write(to: platform, atomically: true, encoding: .utf8)
        #expect(ToolchainScanner.voltaDefaultNode(platformJSON: platform) == "20.11.1")
    }
}
