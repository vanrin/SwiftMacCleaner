//
//  SwiftMacCleanerTests.swift
//  SwiftMacCleanerTests
//
//  Created by Chhea Vanrin on 6/10/26.
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
}

struct ByteFormatTests {
    @Test func usesDecimalUnitsLikeFinder() {
        #expect(ByteFormat.string(14_200_000_000) == "14.2 GB")
        #expect(ByteFormat.string(380_000_000) == "380 MB")
        #expect(ByteFormat.string(52_000) == "52 KB")
        #expect(ByteFormat.string(0) == "0 KB")
    }

    @Test func rollsOverToTheNextUnitInsteadOfShowingAThousand() {
        #expect(ByteFormat.string(999_700_000) == "1.0 GB")
    }
}

struct SafetyGuardTests {
    @Test func allowsOnlyPathsWellInsideTheRoot() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let safety = SafetyGuard(root: sandbox.root)

        #expect(safety.allows(sandbox.root.appending(path: ".gradle/caches")))
        #expect(safety.allows(sandbox.root.appending(path: "Code/app/node_modules")))
        #expect(safety.allows(sandbox.root.appending(path: "Library/Caches/com.example.app")))

        // The root, its direct children, and whole Library folders are never fair game.
        #expect(!safety.allows(sandbox.root))
        #expect(!safety.allows(sandbox.root.appending(path: "Documents")))
        #expect(!safety.allows(sandbox.root.appending(path: "Library/Caches")))
        #expect(!safety.allows(URL(fileURLWithPath: "/usr/local/lib")))
        #expect(!safety.allows(sandbox.root.appending(path: "Code/app/../../../elsewhere/x")))
    }

    @Test func refusesAPathThatLeavesTheRootThroughASymlink() throws {
        let sandbox = try Sandbox()
        let outside = try Sandbox()
        defer { sandbox.remove(); outside.remove() }
        try outside.file("target/data.bin")
        let link = sandbox.root.appending(path: "Code/link")
        try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside.root.appending(path: "target"))

        let safety = SafetyGuard(root: sandbox.root)
        #expect(!safety.allows(link.appending(path: "data.bin")))
        // The link itself sits inside the root, and removing it does not touch what it points at.
        #expect(safety.allows(link))
    }
}

struct CleanerTests {
    @Test func deletesWhatIsAllowedAndRefusesTheRest() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let safety = SafetyGuard(root: sandbox.root)
        let cache = try sandbox.file("Library/Caches/com.example.app/blob.bin").deletingLastPathComponent()
        let keep = try sandbox.file("Documents/thesis.txt").deletingLastPathComponent()

        #expect(Cleaner.perform(CleanOperation(itemID: "a", kind: .delete(cache)), safety: safety).failure == nil)
        #expect(!Files.exists(cache))

        let refusal = Cleaner.perform(CleanOperation(itemID: "b", kind: .delete(keep)), safety: safety).failure
        #expect(refusal != nil)
        #expect(Files.exists(keep.appending(path: "thesis.txt")))
    }

    @Test func removesASymlinkWithoutFollowingIt() throws {
        let sandbox = try Sandbox()
        let outside = try Sandbox()
        defer { sandbox.remove(); outside.remove() }
        let precious = try outside.file("target/data.bin")
        let link = sandbox.root.appending(path: "Code/link")
        try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: precious.deletingLastPathComponent())

        let result = Cleaner.perform(CleanOperation(itemID: "a", kind: .delete(link)), safety: SafetyGuard(root: sandbox.root))
        #expect(result.failure == nil)
        #expect(Files.exists(precious))
    }

    @Test func deletesFoldersThatWereWrittenReadOnly() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let file = try sandbox.file("go/pkg/mod/readonly/file.go")
        let folder = file.deletingLastPathComponent()
        let readOnly: NSNumber = 0o555
        try FileManager.default.setAttributes([.posixPermissions: readOnly], ofItemAtPath: folder.path)

        let target = sandbox.root.appending(path: "go/pkg")
        #expect(Cleaner.perform(CleanOperation(itemID: "a", kind: .delete(target)), safety: SafetyGuard(root: sandbox.root)).failure == nil)
        #expect(!Files.exists(target))
    }

    @Test func runReportsWhatWasCleanedAndWritesALog() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let good = try sandbox.file(".npm/_cacache/blob.bin").deletingLastPathComponent()
        let finding = Finding(
            id: "f", area: .packageCaches, aftermath: .rebuilds, title: "Caches", summary: "", explanation: "",
            method: .delete, actionTarget: "~/.npm",
            items: [
                FindingItem(id: "f/good", title: "npm", detail: "", size: 10, paths: [good]),
                FindingItem(id: "f/bad", title: "outside", detail: "", size: 10, paths: [URL(fileURLWithPath: "/usr/local/nope")]),
                FindingItem(id: "f/unticked", title: "left", detail: "", size: 10, paths: [sandbox.root.appending(path: ".npm/_npx")]),
            ]
        )
        let plan = CleanPlan.make(findings: [finding], selection: ["f/good", "f/bad"])
        #expect(plan.steps.count == 1)
        #expect(plan.totalSize == 20)

        let outcome = await Cleaner.run(plan: plan, safety: SafetyGuard(root: sandbox.root)) { _ in }
        #expect(outcome.cleanedItemIDs == ["f/good"])
        #expect(outcome.failureCount == 1)
        #expect(!Files.exists(good))
        #expect(outcome.logURL.map(Files.exists) == true)
    }

    @Test func skippedStepsAreLeftAlone() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let folder = try sandbox.file("Library/Developer/Xcode/DerivedData/App-abc/Build/x.o").deletingLastPathComponent()
        let finding = Finding(
            id: "xcode.derivedData", area: .xcode, aftermath: .rebuilds, title: "DerivedData", summary: "", explanation: "",
            method: .delete, actionTarget: "",
            items: [FindingItem(id: "dd/app", title: "App", detail: "", size: 10, paths: [folder])]
        )
        let plan = CleanPlan.make(findings: [finding], selection: ["dd/app"])
        let outcome = await Cleaner.run(plan: plan, safety: SafetyGuard(root: sandbox.root),
                                        skipping: ["xcode.derivedData": "Xcode was still open"]) { _ in }
        #expect(outcome.cleanedItemIDs.isEmpty)
        #expect(Files.exists(folder))
    }
}

/// The whole path behind the Clean button, on a throwaway folder.
@MainActor
struct AppModelCleanTests {
    private func finding(id: String, items: [FindingItem], waitsFor: InUseCheck? = nil) -> Finding {
        Finding(id: id, area: .packageCaches, aftermath: .rebuilds, title: id, summary: "", explanation: "",
                method: .delete, actionTarget: "", items: items, waitsFor: waitsFor)
    }

    private func waitUntilDone(_ cleanUp: CleanUpModel) async throws {
        for _ in 0..<200 where cleanUp.phase != .done {
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    @Test func cleaningRemovesOnlyTheTickedItemsAndShowsTheResult() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let npm = try sandbox.file(".npm/_cacache/blob.bin").deletingLastPathComponent()
        let maven = try sandbox.file(".m2/repository/lib.jar").deletingLastPathComponent()

        let model = AppModel(home: sandbox.root)
        let overview = model.cleanUp(.developer)
        overview.show(findings: [finding(id: "caches", items: [
            FindingItem(id: "c/npm", title: "npm", detail: "", size: 10, paths: [npm]),
            FindingItem(id: "c/maven", title: "Maven", detail: "", size: 10, paths: [maven], preselected: false),
        ])])
        #expect(overview.selection == ["c/npm"])

        overview.clean()
        try await waitUntilDone(overview)

        #expect(overview.phase == .done)
        #expect(!Files.exists(npm))
        #expect(Files.exists(maven))
        #expect(overview.findings.first?.items.map(\.id) == ["c/maven"])
        #expect(overview.outcome?.failureCount == 0)
        #expect(overview.outcome?.logURL.map(Files.exists) == true)
    }

    @Test func aStepWhoseAppIsOpenIsLeftAloneAndTheAppIsNotAskedToQuit() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let derived = try sandbox.file("Library/Developer/Xcode/DerivedData/App-abc/x.o").deletingLastPathComponent()
        let cache = try sandbox.file(".npm/_cacache/blob.bin").deletingLastPathComponent()

        let model = AppModel(home: sandbox.root)
        let overview = model.cleanUp(.developer)
        // Finder is always running, so it stands in for an open Xcode.
        overview.show(findings: [
            finding(id: "derived", items: [FindingItem(id: "d/app", title: "App", detail: "", size: 10, paths: [derived])],
                    waitsFor: .app(bundleID: "com.apple.finder", name: "Finder")),
            finding(id: "caches", items: [FindingItem(id: "c/npm", title: "npm", detail: "", size: 10, paths: [cache])]),
        ])
        #expect(overview.blockedSteps(in: overview.plan).keys.sorted() == ["derived"])

        overview.clean()
        try await waitUntilDone(overview)

        #expect(Files.exists(derived))
        #expect(!Files.exists(cache))
        #expect(model.isRunning(bundleID: "com.apple.finder"))
        #expect(overview.outcome?.steps.first { $0.id == "derived" }?.skippedReason != nil)
        #expect(overview.findings.map(\.id) == ["derived"])
    }
}

struct CleanPlanTests {
    @Test func shellScriptQuotesAwkwardPaths() {
        let finding = Finding(
            id: "f", area: .projects, aftermath: .rebuilds, title: "Projects", summary: "", explanation: "",
            method: .delete, actionTarget: "",
            items: [FindingItem(id: "f/1", title: "", detail: "", size: 1,
                                paths: [URL(fileURLWithPath: "/Users/me/Code/it's mine/node_modules")])]
        )
        let script = CleanPlan.make(findings: [finding], selection: ["f/1"]).shellScript()
        #expect(script.contains(#"rm -rf -- '/Users/me/Code/it'\''s mine/node_modules'"#))
    }

    @Test func commandFindingsBecomeRunOperations() {
        let finding = Finding(
            id: "docker.unused", area: .containers, aftermath: .downloadsAgain, title: "Docker", summary: "", explanation: "",
            method: .command, actionTarget: "docker image prune",
            items: [FindingItem(id: "d/images", title: "", detail: "", size: 5,
                                command: ["/usr/local/bin/docker", "image", "prune", "--all", "--force"])]
        )
        let plan = CleanPlan.make(findings: [finding], selection: ["d/images"])
        #expect(plan.steps.first?.operations == [
            CleanOperation(itemID: "d/images", kind: .run(["/usr/local/bin/docker", "image", "prune", "--all", "--force"]), size: 5),
        ])
        #expect(plan.trashedSize == 0)
    }
}

struct FileSizerTests {
    @Test func measuresAFolderAndCountsHardLinksOnce() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let original = try sandbox.file("store/blob.bin", bytes: 2_000_000)
        let linked = sandbox.root.appending(path: "store/linked.bin")
        try FileManager.default.linkItem(at: original, to: linked)

        let size = FileSizer.allocatedSize(of: sandbox.root.appending(path: "store"))
        #expect(size >= 2_000_000)
        #expect(size < 3_000_000)
    }
}

struct SpaceScannerTests {
    private func measure(_ root: URL) throws -> SpaceNode {
        try #require(SpaceScanner.measure(root: root, threshold: 1_000_000) { _ in })
    }

    @Test func listsBigFoldersAndFilesAndFoldsTheRestIntoSmallerItems() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.file("Movies/holiday.mov", bytes: 5_000_000)
        try sandbox.file("Code/app/node_modules/pkg/index.js", bytes: 3_000_000)
        try sandbox.file("Code/app/src/main.swift", bytes: 4_000)
        try sandbox.file("notes.txt", bytes: 4_000)

        let root = try measure(sandbox.root)
        #expect(root.children.map(\.name) == ["Movies", "Code"])
        #expect(root.size >= 8_000_000)
        #expect(root.smallerItemsSize > 0)
        #expect(root.smallerItemsSize < 100_000)

        // Each level keeps its own big children, and a big file is listed like a folder.
        let movies = try #require(root.children.first)
        #expect(movies.children.map(\.name) == ["holiday.mov"])
        #expect(movies.children.first?.isDirectory == false)
        let app = try #require(root.children.last?.children.first)
        #expect(app.name == "app")
        #expect(app.children.map(\.name) == ["node_modules"])
        // src is far below the threshold, so it only shows up in the remainder.
        #expect(app.smallerItemsSize > 0)
        #expect(!root.isIncomplete)
    }

    @Test func aFolderItCannotOpenIsFlaggedAllTheWayUp() throws {
        let sandbox = try Sandbox()
        let locked = sandbox.root.appending(path: "Library/Private")
        let noAccess: NSNumber = 0o000
        let open: NSNumber = 0o755
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: open], ofItemAtPath: locked.path)
            sandbox.remove()
        }
        try sandbox.file("Library/Private/secret.db", bytes: 3_000_000)
        try sandbox.file("Library/Caches/blob.bin", bytes: 3_000_000)
        try FileManager.default.setAttributes([.posixPermissions: noAccess], ofItemAtPath: locked.path)

        let root = try measure(sandbox.root)
        let library = try #require(root.children.first { $0.name == "Library" })
        let unreadable = try #require(library.children.first { $0.name == "Private" })
        #expect(unreadable.isUnreadable)
        #expect(library.isIncomplete)
        #expect(root.isIncomplete)
        // What could be read is still counted and listed.
        #expect(library.children.contains { $0.name == "Caches" && !$0.isIncomplete })
    }

    @Test func countsAHardLinkedFileOnceAndDoesNotFollowSymlinks() throws {
        let sandbox = try Sandbox()
        let outside = try Sandbox()
        defer { sandbox.remove(); outside.remove() }
        let original = try sandbox.file("store/blob.bin", bytes: 2_000_000)
        try FileManager.default.linkItem(at: original, to: sandbox.root.appending(path: "store/copy.bin"))
        try outside.file("big.bin", bytes: 5_000_000)
        try FileManager.default.createSymbolicLink(at: sandbox.root.appending(path: "link"), withDestinationURL: outside.root)

        let root = try measure(sandbox.root)
        #expect(root.size >= 2_000_000)
        #expect(root.size < 3_000_000)
    }

    @Test func namesASimulatorFolderByItsDeviceInsteadOfItsIdentifier() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let device = sandbox.root.appending(path: "Library/Developer/CoreSimulator/Devices/0D0CC341-95D3")
        try FileManager.default.createDirectory(at: device, withIntermediateDirectories: true)
        let info: [String: Any] = ["name": "iPhone 18 Pro", "runtime": "com.apple.CoreSimulator.SimRuntime.iOS-27-0"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: device.appending(path: "device.plist"))

        #expect(SpaceScanner.friendlyName(forFolderAt: device.path) == "iPhone 18 Pro simulator, iOS 27.0")
        #expect(SpaceScanner.friendlyName(forFolderAt: sandbox.root.appending(path: "Library").path) == nil)
    }

    @Test func aMissingFolderGivesNothing() {
        let missing = URL(fileURLWithPath: "/tmp/mdc-does-not-exist-\(UUID().uuidString)")
        #expect(SpaceScanner.measure(root: missing, threshold: 1) { _ in } == nil)
    }
}

@MainActor
struct SpaceModelTests {
    @Test func measuresThenWalksDownAndBackUp() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.file("Library/Developer/CoreSimulator/device.img", bytes: 25_000_000)
        try sandbox.file("notes.txt")

        let model = SpaceModel(home: sandbox.root)
        model.start()
        #expect(model.phase == .measuring)
        for _ in 0..<200 where model.phase != .done {
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(model.phase == .done)
        #expect(model.title(at: 0) == "Home Folder")

        let library = try #require(model.current?.children.first)
        #expect(library.name == "Library")
        model.open(library)
        model.open(try #require(model.current?.children.first))
        #expect(model.trail.map(\.name).dropFirst() == ["Library", "Developer"])
        #expect(model.displayPath(try #require(model.current).path) == "~/Library/Developer")

        // A file is not somewhere to go, and going back trims the trail.
        let simulator = try #require(model.current?.children.first)
        model.open(simulator)
        model.open(try #require(model.current?.children.first))
        #expect(model.current?.name == "CoreSimulator")
        model.goBack(to: 0)
        #expect(model.trail.count == 1)

        model.reset()
        #expect(model.phase == .idle)
        #expect(model.current == nil)
    }

    @Test func showsPathsOnTheDataVolumeTheWayFinderDoes() {
        let model = SpaceModel(home: URL(fileURLWithPath: "/Users/me"))
        #expect(model.displayPath("/Users/me") == "~")
        #expect(model.displayPath("/Users/me/Code/app") == "~/Code/app")
        #expect(model.displayPath("/System/Volumes/Data/Applications/Xcode.app") == "/Applications/Xcode.app")
        #expect(model.displayPath("/System/Volumes/Data") == "/")
    }
}

struct ProjectScannerTests {
    @Test func offersBuildFoldersOnlyInStaleProjects() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        // Untouched for 200 days.
        try sandbox.file("Code/old-app/package.json", age: 200)
        try sandbox.file("Code/old-app/pnpm-lock.yaml", age: 200)
        try sandbox.file("Code/old-app/src/index.js", age: 200)
        try sandbox.file("Code/old-app/node_modules/pkg/index.js", bytes: 2_000_000, age: 200)
        try sandbox.setAge(200, of: sandbox.root.appending(path: "Code/old-app/node_modules"))
        // Edited today.
        try sandbox.file("Code/fresh-app/package.json")
        try sandbox.file("Code/fresh-app/node_modules/pkg/index.js", bytes: 2_000_000)
        // A folder called "build" with no project file beside it is somebody's data, not build output.
        try sandbox.file("Code/notes/build/plan.txt", bytes: 2_000_000, age: 200)

        let context = ScanContext(home: sandbox.root, staleDays: 60, projectRoots: [sandbox.root.appending(path: "Code")])
        let result = await ProjectScanner.scan(context)

        let items = try #require(result.findings.first).items
        #expect(items.map(\.title) == ["old-app"])
        #expect(items.first?.hint == "pnpm install")
        #expect(items.first?.paths.map(\.lastPathComponent) == ["node_modules"])
        #expect(result.findings.first?.note?.contains("1 project") == true)
    }

    @Test func recognisesGeneratedFoldersByTheirNeighbours() {
        let directory = URL(fileURLWithPath: "/tmp/none")
        #expect(ProjectScanner.isGenerated("node_modules", in: directory, siblings: []))
        #expect(ProjectScanner.isGenerated("Pods", in: directory, siblings: ["Podfile"]))
        #expect(!ProjectScanner.isGenerated("Pods", in: directory, siblings: []))
        #expect(ProjectScanner.isGenerated("build", in: directory, siblings: ["pubspec.yaml"]))
        #expect(!ProjectScanner.isGenerated("build", in: directory, siblings: ["README.md"]))
        #expect(ProjectScanner.isGenerated("target", in: directory, siblings: ["Cargo.toml"]))
        #expect(!ProjectScanner.isGenerated("src", in: directory, siblings: ["package.json"]))
    }
}

struct XcodeScannerTests {
    private let context = ScanContext(home: URL(fileURLWithPath: "/Users/me"), staleDays: 60)

    @Test func readsTheOSVersionFromADeviceSupportFolderName() {
        #expect(XcodeScanner.majorVersion(in: "17.5 (21F79)") == 17)
        #expect(XcodeScanner.majorVersion(in: "iPhone15,2 18.1 (22B83)") == 18)
        #expect(XcodeScanner.majorVersion(in: "Watch6,1 10.5 (21T576)") == 10)
        #expect(XcodeScanner.majorVersion(in: "notes") == nil)
    }

    @Test func namesADerivedDataFolderByItsProject() {
        #expect(XcodeScanner.projectName(fromFolder: "Runner-efqyvivbwxtfildrzuocdqizemmj") == "Runner")
        #expect(XcodeScanner.projectName(fromFolder: "My-App-efqyvivbwxtfildrzuocdqizemmj") == "My-App")
        #expect(XcodeScanner.projectName(fromFolder: "ModuleCache.noindex") == nil)
        #expect(XcodeScanner.projectName(fromFolder: "SDKExplicitPrecompiledModules") == nil)
    }

    @Test func labelsALeftoverFolderAndLeavesOutRecentBuilds() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let derived = "Library/Developer/Xcode/DerivedData"
        try sandbox.file("\(derived)/Leftover-efqyvivbwxtfildrzuocdqizemmj/Build/a.o", bytes: 2_000_000)
        try sandbox.file("\(derived)/ModuleCache.noindex/a.pcm", bytes: 2_000_000)
        for (name, age) in [("Old-babveuznijdacjghtyzmidimmdjj", 90.0), ("Fresh-diijkpecsjmrfkchfmtdfggivvlm", 1.0)] {
            try sandbox.file("\(derived)/\(name)/Build/a.o", bytes: 2_000_000)
            let info: [String: Any] = ["LastAccessedDate": Date().addingTimeInterval(-age * 86_400)]
            try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
                .write(to: sandbox.root.appending(path: "\(derived)/\(name)/info.plist"))
        }

        let result = await XcodeScanner.scan(ScanContext(home: sandbox.root))
        let finding = try #require(result.findings.first { $0.id == "xcode.derivedData" })
        let details = Dictionary(uniqueKeysWithValues: finding.items.map { ($0.title, $0.detail) })
        #expect(Set(details.keys) == ["Leftover", "ModuleCache.noindex", "Old"])
        #expect(details["Leftover"] == "Leftover build folder with no project record")
        #expect(details["ModuleCache.noindex"] == "Shared build cache")
        #expect(finding.note?.contains("1 project built in the last 7 days") == true)
    }

    @Test func namesARuntimeFromItsIdentifier() {
        #expect(XcodeScanner.runtimeName(fromKey: "com.apple.CoreSimulator.SimRuntime.iOS-17-0") == "iOS 17.0")
    }

    @Test func offersUnavailableAndLongUnusedSimulatorDevices() {
        let old = ISO8601DateFormatter().string(from: context.now.addingTimeInterval(-200 * 86_400))
        let recent = ISO8601DateFormatter().string(from: context.now.addingTimeInterval(-2 * 86_400))
        let json = """
        {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-17-0": [
          {"udid": "OLD", "name": "iPhone 15", "state": "Shutdown", "isAvailable": true, "dataPathSize": 3000000000, "lastUsedAt": "\(old)"},
          {"udid": "NEW", "name": "iPhone 16", "state": "Shutdown", "isAvailable": true, "dataPathSize": 3000000000, "lastUsedAt": "\(recent)"},
          {"udid": "RUN", "name": "iPhone 14", "state": "Booted", "isAvailable": true, "dataPathSize": 3000000000, "lastUsedAt": "\(old)"},
          {"udid": "GONE", "name": "iPhone 12", "state": "Shutdown", "isAvailable": false, "dataPathSize": 1000000000}
        ]}}
        """
        let items = XcodeScanner.deviceItems(fromJSON: json, xcrun: "/usr/bin/xcrun", context: context)
        #expect(Set(items.map(\.id)) == ["xcode.simulators/unavailable", "xcode.simulators/device/OLD"])
        #expect(items.first { $0.id.hasSuffix("OLD") }?.command == ["/usr/bin/xcrun", "simctl", "delete", "OLD"])
    }

    @Test func offersOnlyRuntimesNotUsedLately() {
        let old = ISO8601DateFormatter().string(from: context.now.addingTimeInterval(-200 * 86_400))
        let recent = ISO8601DateFormatter().string(from: context.now.addingTimeInterval(-2 * 86_400))
        let json = """
        {
          "A": {"identifier": "A", "version": "17.0", "platformIdentifier": "com.apple.platform.iphonesimulator", "sizeBytes": 7000000000, "state": "Ready", "deletable": true, "lastUsedAt": "\(old)"},
          "B": {"identifier": "B", "version": "26.5", "platformIdentifier": "com.apple.platform.iphonesimulator", "sizeBytes": 10000000000, "state": "Ready", "deletable": true, "lastUsedAt": "\(recent)"},
          "C": {"identifier": "C", "version": "27.0", "platformIdentifier": "com.apple.platform.iphonesimulator", "sizeBytes": 10000000000, "state": "Ready", "deletable": true},
          "D": {"identifier": "D", "version": "16.0", "platformIdentifier": "com.apple.platform.iphonesimulator", "sizeBytes": 6000000000, "state": "Ready", "deletable": false, "lastUsedAt": "\(old)"}
        }
        """
        let items = XcodeScanner.runtimeItems(fromJSON: json, xcrun: "/usr/bin/xcrun", context: context)
        #expect(items.map(\.title) == ["iOS 17.0 Simulator runtime"])
        #expect(items.first?.command == ["/usr/bin/xcrun", "simctl", "runtime", "delete", "A"])
    }
}

struct DockerScannerTests {
    @Test func readsDockerSizes() {
        #expect(ContainersScanner.bytes(from: "10.2GB (80%)") == 10_200_000_000)
        #expect(ContainersScanner.bytes(from: "512.3MB") == 512_300_000)
        #expect(ContainersScanner.bytes(from: "45kB (3%)") == 45_000)
        #expect(ContainersScanner.bytes(from: "0B (0%)") == 0)
    }

    @Test func turnsDiskUsageRowsIntoPruneCommandsAndLeavesVolumesAlone() {
        let output = """
        {"Active":"2","Reclaimable":"10.2GB (80%)","Size":"12.7GB","TotalCount":"14","Type":"Images"}
        {"Active":"1","Reclaimable":"120MB (40%)","Size":"300MB","TotalCount":"7","Type":"Containers"}
        {"Active":"3","Reclaimable":"4GB (50%)","Size":"8GB","TotalCount":"6","Type":"Local Volumes"}
        {"Active":"0","Reclaimable":"2.1GB","Size":"2.1GB","TotalCount":"90","Type":"Build Cache"}
        """
        let items = ContainersScanner.items(from: ContainersScanner.parse(output), docker: "/usr/local/bin/docker")
        #expect(items.map(\.id) == ["docker.unused/images", "docker.unused/buildCache", "docker.unused/containers"])
        #expect(items.first?.detail == "12 of 14 images are not used by any container")
        #expect(items.allSatisfy { $0.command?.contains("volume") == false })
    }
}

struct ToolchainScannerTests {
    @Test func keepsTheDefaultAndTheNewestNodeVersion() {
        let versions = ["v16.20.2", "v18.19.0", "v20.11.1", "v22.3.0"]
        #expect(ToolchainScanner.nodeVersionsInUse(versions, defaultAlias: "18") == ["v18.19.0", "v22.3.0"])
        #expect(ToolchainScanner.nodeVersionsInUse(versions, defaultAlias: "v20.11.1") == ["v20.11.1", "v22.3.0"])
        // An alias such as "lts/*" cannot be resolved here, so only the newest is assumed to be in use.
        #expect(ToolchainScanner.nodeVersionsInUse(versions, defaultAlias: "lts/*") == ["v22.3.0"])
    }
}

struct ShellTests {
    @Test func capturesOutputAndExitStatus() throws {
        let output = try #require(Shell.run("/bin/sh", ["-c", "echo hello; echo oops >&2; exit 3"]))
        #expect(output.stdout == "hello\n")
        #expect(output.stderr == "oops\n")
        #expect(output.status == 3)
        #expect(!output.succeeded)
    }

    @Test func aCancelledTaskStopsTheTool() async throws {
        let started = Date()
        let task = Task.detached { Shell.run("/bin/sleep", ["30"], timeout: 60) }
        try await Task.sleep(for: .milliseconds(400))
        task.cancel()
        let output = try #require(await task.value)
        #expect(output.cancelled)
        #expect(!output.succeeded)
        #expect(Date().timeIntervalSince(started) < 5)
    }

    @Test func givesUpOnAToolThatHangs() throws {
        let started = Date()
        let output = try #require(Shell.run("/bin/sleep", ["30"], timeout: 0.5))
        #expect(output.timedOut)
        #expect(!output.succeeded)
        #expect(Date().timeIntervalSince(started) < 5)
    }

    @Test func findsToolsWithoutRelyingOnPATH() {
        #expect(Shell.which("xcrun") == "/usr/bin/xcrun")
        #expect(Shell.which("no-such-tool-here") == nil)
    }
}

struct DownloadsAndTrashScannerTests {
    @Test func namesTheFolderItCouldNotReadAndStillScansTheOther() async throws {
        let sandbox = try Sandbox()
        let downloads = sandbox.root.appending(path: "Downloads")
        let locked: NSNumber = 0o000
        let open: NSNumber = 0o755
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: open], ofItemAtPath: downloads.path)
            sandbox.remove()
        }
        try sandbox.file("Downloads/Installer.dmg", bytes: 6_000_000)
        try sandbox.file(".Trash/old-video.mov", bytes: 6_000_000)
        try FileManager.default.setAttributes([.posixPermissions: locked], ofItemAtPath: downloads.path)

        let context = ScanContext(home: sandbox.root)
        for result in [await InstallerScanner.scan(context), await LargeFileScanner.scan(context)] {
            #expect(result.unreadable == ["Downloads"])
            #expect(result.findings.isEmpty)
            #expect(result.skipReason?.contains("Downloads") == true)
        }
        let trash = await TrashScanner.scan(context)
        #expect(trash.unreadable.isEmpty)
        #expect(trash.findings.map(\.id) == ["trash.items"])
        #expect(trash.findings.first?.area == .trash)
        #expect(trash.skipReason == nil)
    }

    @Test func aMissingFolderIsNotAPermissionProblem() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let context = ScanContext(home: sandbox.root)
        for result in [await InstallerScanner.scan(context), await LargeFileScanner.scan(context), await TrashScanner.scan(context)] {
            #expect(result.unreadable.isEmpty)
            #expect(result.findings.isEmpty)
            #expect(result.skipReason == nil)
        }
    }
}

struct CachesLogsScannerTests {
    @Test func namesACacheFolderByItsApp() {
        #expect(CachesLogsScanner.displayName("com.google.Chrome") == "Chrome")
        #expect(CachesLogsScanner.displayName("com.microsoft.VSCode.ShipIt") == "VSCode")
        #expect(CachesLogsScanner.displayName("com.superace.updf.mac") == "updf")
        #expect(CachesLogsScanner.displayName("com.spotify.client") == "spotify")
        #expect(CachesLogsScanner.displayName("JetBrains") == "JetBrains")
    }
}

struct AndroidScannerTests {
    @Test func offersOnlyEmulatorsThatHaveNotRunLately() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.file(".android/avd/Old_Phone.avd/userdata.img", bytes: 21_000_000)
        try sandbox.file(".android/avd/Old_Phone.ini")
        try sandbox.setAge(200, of: sandbox.root.appending(path: ".android/avd/Old_Phone.avd"))
        try sandbox.file(".android/avd/Daily_Phone.avd/userdata.img", bytes: 21_000_000)

        let result = await AndroidScanner.scan(ScanContext(home: sandbox.root, staleDays: 60))
        let finding = try #require(result.findings.first { $0.id == "android.emulators" })
        #expect(finding.items.map(\.title) == ["Old Phone emulator"])
        #expect(finding.items.first?.paths.map(\.lastPathComponent) == ["Old_Phone.avd", "Old_Phone.ini"])
        #expect(finding.note == "Left out on purpose: 1 emulator used in the last 60 days.")
    }

    @Test func readsWhichSystemImageAnEmulatorUses() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let config = try sandbox.file(".android/avd/Pixel_8.avd/config.ini")
        try "hw.ramSize=2048\nimage.sysdir.1 = system-images/android-34/google_apis/arm64-v8a/\n"
            .write(to: config, atomically: true, encoding: .utf8)
        #expect(AndroidScanner.systemImagePath(forEmulatorAt: config.deletingLastPathComponent())
                == "system-images/android-34/google_apis/arm64-v8a")
    }
}
