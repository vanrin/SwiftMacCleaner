//
//  StackTests.swift
//  Mac Disk CleanerTests
//

import Foundation
import Testing
@testable import Mac_Disk_Cleaner

/// A throwaway folder that stands in for a home directory.
private struct Sandbox {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "mdc-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    @discardableResult
    func file(_ path: String, bytes: Int = 16) throws -> URL {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 7, count: bytes).write(to: url)
        return url
    }

    /// A stand-in for a command-line tool: a script that prints the given lines.
    @discardableResult
    func tool(_ path: String, printing lines: [String], status: Int = 0) throws -> URL {
        let url = try file(path)
        let script = (["#!/bin/sh"] + lines.map { "echo \"\($0)\"" } + ["exit \(status)"]).joined(separator: "\n")
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    /// A scan of this folder that carries the given shell variables and none of the Mac's own tools.
    func context(shell variables: [String: String]) -> ScanContext {
        var context = ScanContext(home: root)
        let environment = ShellEnvironment(variables: variables, usualDirectories: [])
        context.shell = Task { environment }
        return context
    }
}

struct StackDetectorTests {
    @Test func findsOnlyTheAreasWhoseToolsLeftSomething() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.file(".npm/_cacache/blob")
        try sandbox.file(".pub-cache/hosted/pub.dev/pkg")
        try sandbox.file(".gradle/caches/jar")
        try sandbox.file("Library/Application Support/Google/AndroidStudio2025.1/options.xml")

        let stack = StackDetector.detect(home: sandbox.root, searchDirectories: [])
        #expect(stack.found[.packageCaches] == ["npm", "Dart and Flutter"])
        #expect(stack.found[.android] == ["Gradle"])
        #expect(stack.found[.ides] == ["Android Studio"])
        #expect(!stack.applies(.xcode))
        #expect(!stack.applies(.containers))
        #expect(!stack.applies(.models))
        // Areas every Mac has do not depend on any tool.
        #expect(stack.applies(.cachesLogs))
        #expect(stack.applies(.snapshots))
    }

    @Test func aToolOnThePathCountsBeforeItHasLeftAnyFolder() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.tool("bin/docker", printing: [])

        #expect(StackDetector.detect(home: sandbox.root, searchDirectories: []).found.isEmpty)
        let stack = StackDetector.detect(home: sandbox.root, searchDirectories: [sandbox.root.appending(path: "bin").path])
        #expect(stack.found == [.containers: ["Docker"]])
    }

    /// A catalog line nobody wrote a sign for would be offered on some Macs and never scanned on others.
    @Test func everyCatalogFolderSitsUnderASign() {
        for group in Catalog.allGroups where group.area.isDeveloper {
            for location in group.locations {
                let covered = StackDetector.signs.contains { sign in
                    sign.area == group.area && sign.paths.contains { location.path == $0 || location.path.hasPrefix($0 + "/") }
                }
                #expect(covered, "\(group.id): nothing detects \(location.path)")
            }
        }
    }

    @Test func everyProjectFileTheScanKnowsNamesAKind() {
        for marker in ProjectScanner.markerFiles {
            #expect(StackDetector.projectKinds.contains { $0.markers.contains(marker) }, "\(marker) names no kind of project")
        }
        #expect(Set(StackDetector.projectKinds.map(\.name)).count == StackDetector.projectKinds.count)
    }

    @Test func readsTheKindsOfProjectNearTheTopOfTheProjectFolders() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.file("Code/shop/package.json")
        try sandbox.file("Code/shop/node_modules/dep/Cargo.toml")
        try sandbox.file("Code/work/api/pom.xml")
        try sandbox.file("Code/mobile/Runner.xcodeproj/project.pbxproj")
        try sandbox.file("Code/a/b/c/d/go.mod")

        let kinds = await StackDetector.projectKinds(in: [sandbox.root.appending(path: "Code")], home: sandbox.root)
        // Dependencies are other people's projects, and a file four folders down is too deep to be worth the walk.
        #expect(kinds.map(\.name) == ["Xcode", "Node", "Maven"])
    }

    @Test func projectFoldersBehindAPermissionPromptAreLeftForTheScan() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.file("Documents/Code/shop/package.json")

        let root = sandbox.root.appending(path: "Documents/Code")
        #expect(StackDetector.raisesPrompt(root, home: sandbox.root))
        #expect(!StackDetector.raisesPrompt(sandbox.root.appending(path: "Code"), home: sandbox.root))
        #expect(await StackDetector.projectKinds(in: [root], home: sandbox.root).isEmpty)
    }

    @Test func aKindOfProjectSwitchesOnTheAreaItsToolsFill() throws {
        let gradle = try #require(StackDetector.projectKinds.first { $0.name == "Gradle" })

        // Gradle projects but no ~/.gradle: the folder may have been moved, so the area is still looked at.
        let moved = DetectedStack().adding([gradle], hasProjectFolders: true)
        #expect(moved.found[.projects] == ["Gradle"])
        #expect(moved.found[.android] == ["Gradle projects"])

        var known = DetectedStack()
        known.add("Gradle", to: .android)
        #expect(known.adding([gradle], hasProjectFolders: true).found[.android] == ["Gradle"])
    }

    @Test func projectsApplyToAnyoneWithProjectFoldersOrDeveloperTools() {
        #expect(!DetectedStack().adding([], hasProjectFolders: false).applies(.projects))
        #expect(DetectedStack().adding([], hasProjectFolders: true).applies(.projects))
        var stack = DetectedStack()
        stack.add("npm", to: .packageCaches)
        #expect(stack.adding([], hasProjectFolders: false).applies(.projects))
    }

    @Test func anAreaThatDoesNotApplyIsScannedOnlyWhenAskedFor() {
        var stack = DetectedStack()
        for name in ["npm", "pnpm", "Yarn", "Bun", "Deno", "Cargo", "Go"] { stack.add(name, to: .packageCaches) }
        stack.add("npm", to: .packageCaches)

        #expect(stack.scans(.packageCaches, disabled: [], forced: []))
        #expect(!stack.scans(.packageCaches, disabled: [.packageCaches], forced: []))
        #expect(!stack.scans(.android, disabled: [], forced: []))
        #expect(stack.scans(.android, disabled: [], forced: [.android]))
        #expect(stack.scans(.installersTrash, disabled: [], forced: []))

        #expect(stack.summary(of: .packageCaches) == "npm, pnpm, Yarn, Bun, Deno and 2 more")
        #expect(stack.summary(of: .android) == nil)
    }
}

struct ShellEnvironmentTests {
    @Test func readsTheVariablesBetweenTheMarkersAndNothingAround() {
        let output = "Last login: today\nMARKPATH=/a:/b\0CARGO_HOME=/x/cargo\0NOTE=one\ntwo=2\0MARKbye\n"
        #expect(ShellEnvironment.variables(in: output, between: "MARK")
                == ["PATH": "/a:/b", "CARGO_HOME": "/x/cargo", "NOTE": "one\ntwo=2"])
        #expect(ShellEnvironment.variables(in: "no markers here", between: "MARK") == nil)
        #expect(ShellEnvironment.variables(in: "MARKMARK", between: "MARK") == nil)
    }

    @Test func aVariableNamesAFolderOnlyWhenItIsAFullPath() {
        let environment = ShellEnvironment(variables: ["FULL": "/x/y/", "RELATIVE": "caches", "EMPTY": " ", "OFF": "0"])
        #expect(environment.folder(named: "FULL")?.path == "/x/y")
        #expect(environment.folder(named: "RELATIVE") == nil)
        #expect(environment.folder(named: "EMPTY") == nil)
        #expect(environment.folder(named: "OFF") == nil)
        #expect(environment.folder(named: "MISSING") == nil)
    }

    @Test func theShellsPathComesBeforeTheUsualPlaces() {
        let environment = ShellEnvironment(variables: ["PATH": "/custom/bin:/usr/bin:relative"], usualDirectories: ["/usr/bin", "/opt/bin"])
        #expect(environment.searchDirectories == ["/custom/bin", "/usr/bin", "/opt/bin"])
    }

    @Test func asksAToolAndTakesTheFolderItPrints() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.tool("bin/pkg", printing: ["warning: config is old", "$PKG_HOME/cache"])
        try sandbox.tool("bin/broken", printing: ["/somewhere"], status: 1)
        let environment = ShellEnvironment(
            variables: ["PATH": sandbox.root.appending(path: "bin").path, "PKG_HOME": "/x/pkg"], usualDirectories: []
        )

        #expect(environment.folder(printedBy: "pkg", ["cache", "dir"], startingIn: sandbox.root)?.path == "/x/pkg/cache")
        #expect(environment.folder(printedBy: "broken", [], startingIn: sandbox.root) == nil)
        #expect(environment.folder(printedBy: "missing", [], startingIn: sandbox.root) == nil)
    }

    /// Apple's stand-ins in /usr/bin can raise a prompt to install the developer tools.
    @Test func neverRunsAToolFromUsrBin() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let environment = ShellEnvironment(variables: ["PATH": "/usr/bin"], usualDirectories: [])
        #expect(environment.which("env") == "/usr/bin/env")
        #expect(environment.folder(printedBy: "env", [], startingIn: sandbox.root) == nil)
    }
}

struct MovedLocationTests {
    @Test func aFolderAVariableMovedIsOfferedForReviewAndNeverTicked() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.file(".npm/_cacache/blob", bytes: 6_000_000)
        try sandbox.file("tools/cargo/registry/crate", bytes: 6_000_000)
        let context = sandbox.context(shell: ["CARGO_HOME": sandbox.root.appending(path: "tools/cargo").path])

        let report = await CatalogScanner.report(for: Catalog.packageCaches, context: context)
        #expect(report.findings.map(\.id) == ["packages.caches", "packages.caches.moved"])
        #expect(report.protected.isEmpty)

        // The reviewed folder is still the only thing that is deleted outright and ticked.
        let usual = try #require(report.findings.first)
        #expect(usual.tier == .safe)
        #expect(usual.items.map(\.title) == ["npm cache"])

        let moved = try #require(report.findings.last)
        #expect(moved.tier == .review)
        #expect(moved.method == .trash)
        #expect(moved.items.map(\.title) == ["Cargo registry"])
        #expect(moved.items.first?.preselected == false)
        #expect(moved.items.first?.detail.hasSuffix("Found through CARGO_HOME") == true)
        #expect(moved.items.first?.hint == "~/tools/cargo/registry")
        let path = try #require(moved.items.first?.paths.first)
        #expect(SafetyGuard(root: sandbox.root).allows(path))
    }

    @Test func aFolderInItsUsualPlaceIsNotOfferedTwice() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.file(".cargo/registry/crate", bytes: 6_000_000)
        try sandbox.file("Library/Caches/uv/wheel", bytes: 6_000_000)
        let context = sandbox.context(shell: [
            "CARGO_HOME": sandbox.root.appending(path: ".cargo").path,
            // Some people point XDG at ~/Library/Caches, where the general cache scan already looks.
            "XDG_CACHE_HOME": sandbox.root.appending(path: "Library/Caches").path,
        ])

        let report = await CatalogScanner.report(for: Catalog.packageCaches, context: context)
        #expect(report.findings.map(\.id) == ["packages.caches"])
        #expect(report.findings.first?.items.map(\.title) == ["Cargo registry"])
    }

    /// A variable that points above a reviewed folder would have the same files offered twice.
    @Test func aFolderThatHoldsAReviewedOneIsNotOffered() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.file(".cache/node/corepack/pnpm", bytes: 6_000_000)
        let context = sandbox.context(shell: ["COREPACK_HOME": sandbox.root.appending(path: ".cache/node").path])

        let report = await CatalogScanner.report(for: Catalog.packageCaches, context: context)
        #expect(report.findings.map(\.id) == ["packages.caches"])
        #expect(report.findings.first?.items.map(\.title) == ["Corepack cache"])
    }

    @Test func aFolderOutsideHomeIsListedAsLeftAlone() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let elsewhere = try Sandbox()
        defer { elsewhere.remove() }
        try elsewhere.file("gradle/caches/jar", bytes: 2_000_000)
        let context = sandbox.context(shell: ["GRADLE_USER_HOME": elsewhere.root.appending(path: "gradle").path])

        let report = await CatalogScanner.report(for: Catalog.gradle, context: context)
        #expect(report.findings.isEmpty)
        #expect(report.protected.map(\.rule) == [.otherDisk])
        #expect(report.protected.first?.title == "Gradle dependencies and build cache")
        #expect(report.protected.first?.why.hasPrefix("GRADLE_USER_HOME points at ") == true)
        #expect(report.protected.first?.why.hasSuffix("outside your home folder") == true)

        // The area is not reported as missing when the only thing found is somewhere it cannot clean.
        let result = await AndroidScanner.scan(context)
        #expect(result.skipReason == nil)
        #expect(result.protected.count == 1)
    }

    @Test func aMovedFolderWaitsForTheSameToolAsTheUsualOne() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.file("build/gradle-home/caches/jar", bytes: 2_000_000)
        let context = sandbox.context(shell: ["GRADLE_USER_HOME": sandbox.root.appending(path: "build/gradle-home").path])

        let report = await CatalogScanner.report(for: Catalog.gradle, context: context)
        let moved = try #require(report.findings.first)
        #expect(moved.id == "android.gradle.moved")
        #expect(moved.waitsFor == Catalog.gradle.waitsFor)
        #expect(moved.waitsFor != nil)
    }

    @Test func aToolsOwnAnswerIsUsedForEveryFolderItKeepsThere() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let store = sandbox.root.appending(path: "store/npm")
        try sandbox.tool("bin/npm", printing: [store.path])
        try sandbox.file("store/npm/_cacache/blob", bytes: 6_000_000)
        try sandbox.file("store/npm/_npx/blob", bytes: 7_000_000)
        let context = sandbox.context(shell: ["PATH": sandbox.root.appending(path: "bin").path])

        let report = await CatalogScanner.report(for: Catalog.packageCaches, context: context)
        let moved = try #require(report.findings.first { $0.id == "packages.caches.moved" })
        #expect(moved.items.map(\.title) == ["npx cache", "npm cache"])
        #expect(moved.items.allSatisfy { $0.detail.hasSuffix("Found through npm config get cache") })
    }

    @Test func foldersUnderDotCacheFollowXDG() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.file("xdg/uv/wheel", bytes: 6_000_000)
        let context = sandbox.context(shell: ["XDG_CACHE_HOME": sandbox.root.appending(path: "xdg").path])

        let report = await CatalogScanner.report(for: Catalog.packageCaches, context: context)
        #expect(report.findings.map(\.id) == ["packages.caches.moved"])
        #expect(report.findings.first?.items.map(\.title) == ["uv cache"])
        #expect(report.findings.first?.items.first?.detail.hasSuffix("Found through XDG_CACHE_HOME") == true)
    }

    /// A group that already goes to the Trash unticked has nothing stricter to move its folders into.
    @Test func aReviewGroupKeepsMovedFoldersInTheSameFinding() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.file("gopath/pkg/mod/cache/blob", bytes: 51_000_000)
        let context = sandbox.context(shell: ["GOMODCACHE": sandbox.root.appending(path: "gopath/pkg/mod").path])

        let report = await CatalogScanner.report(for: Catalog.goModules, context: context)
        #expect(report.findings.map(\.id) == ["packages.goModules"])
        let finding = try #require(report.findings.first)
        #expect(finding.method == .trash)
        #expect(finding.actionTarget == CatalogScanner.eachRowTarget)
        #expect(finding.items.first?.preselected == false)
        #expect(finding.items.first?.hint == "~/gopath/pkg/mod")
    }

    @Test func withoutAShellEnvironmentOnlyTheUsualFoldersAreLookedAt() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.file(".npm/_cacache/blob", bytes: 6_000_000)

        let report = await CatalogScanner.report(for: Catalog.packageCaches, context: ScanContext(home: sandbox.root))
        #expect(report.findings.map(\.id) == ["packages.caches"])
        #expect(report.protected.isEmpty)
    }

    @Test func aMovedHuggingFaceCacheIsStillOfferedOneRepositoryAtATime() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let old = try sandbox.file("ai/hf/hub/models--old--one/blobs/a.bin", bytes: 120_000_000)
        let age = Date().addingTimeInterval(-200 * 86_400)
        try FileManager.default.setAttributes([.modificationDate: age],
                                              ofItemAtPath: old.deletingLastPathComponent().deletingLastPathComponent().path)
        try sandbox.file("ai/hf/hub/models--fresh--two/blobs/a.bin", bytes: 120_000_000)
        var context = sandbox.context(shell: ["HF_HOME": sandbox.root.appending(path: "ai/hf").path])
        context.staleDays = 60

        let result = await ModelsScanner.scan(context)
        let finding = try #require(result.findings.first { $0.id == "models.downloads" })
        #expect(finding.items.map(\.title) == ["old/one"])
        #expect(finding.items.first?.paths.first?.path.hasSuffix("/ai/hf/hub/models--old--one") == true)
        #expect(result.protected.map(\.title) == ["fresh/two (Hugging Face model)"])
    }
}
