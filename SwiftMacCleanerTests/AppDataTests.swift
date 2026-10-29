//
//  AppDataTests.swift
//  SwiftMacCleanerTests
//
//  Telegram's media, the model Chrome downloads, and the caches browsers and web apps keep in
//  Application Support.
//

import Foundation
import Testing
@testable import SwiftMacCleaner

/// A throwaway folder that stands in for a home directory.
private struct Sandbox {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "mdc-appdata-\(UUID().uuidString)")
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

    func url(_ path: String) -> URL { root.appending(path: path) }
}

/// Paths as the file system names them, so /var and /private/var, or a trailing slash, do not matter.
private func resolved(_ urls: [URL]) -> Set<String> {
    Set(urls.map { $0.resolvingSymlinksInPath().path })
}

struct ChatMediaTests {
    private let telegram = "Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram"

    @Test func offersEveryAccountsMediaButNotItsMessages() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.file("\(telegram)/appstore/account-111/postbox/media/photo-1")
        try sandbox.file("\(telegram)/appstore/account-111/postbox/db/db_sqlite")
        try sandbox.file("\(telegram)/stable/account-222/postbox/media/cache/video-1")
        try sandbox.file("\(telegram)/appstore/accounts-metadata/guard_db/x")

        let finding = try #require(await AppDataScanner.downloaded(ScanContext(home: sandbox.root), minimumSize: 1))
        #expect(finding.aftermath == .downloadsAgain)
        #expect(finding.method == .trash)
        #expect(finding.smart == nil, "Media that has to be downloaded again is never ticked for the user")
        let paths = finding.items.flatMap(\.paths)
        #expect(resolved(paths) == resolved([sandbox.url("\(telegram)/appstore/account-111/postbox/media"),
                          sandbox.url("\(telegram)/stable/account-222/postbox/media")]))
        #expect(finding.items.allSatisfy { $0.keptBy == "ru.keepcoder.Telegram" })
    }

    @Test func offersChromesModelAndWaitsForChrome() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.file("Library/Application Support/Google/Chrome/OptGuideOnDeviceModel/2025.1/weights.bin")

        let finding = try #require(await AppDataScanner.downloaded(ScanContext(home: sandbox.root), minimumSize: 1))
        let item = try #require(finding.items.first)
        #expect(item.title == "Chrome on-device AI model")
        #expect(item.keptBy == "com.google.Chrome")
        #expect(resolved(item.paths) == resolved([sandbox.url("Library/Application Support/Google/Chrome/OptGuideOnDeviceModel")]))
    }

    @Test func findsNothingWhenNeitherAppIsThere() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        #expect(await AppDataScanner.downloaded(ScanContext(home: sandbox.root), minimumSize: 1) == nil)
    }
}

struct WebCacheTests {
    private let chrome = "Library/Application Support/Google/Chrome"

    @Test func offersEngineCachesAndLeavesOfflineSiteDataUnticked() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        for profile in ["Default", "Profile 1"] {
            try sandbox.file("\(chrome)/\(profile)/Preferences")
            try sandbox.file("\(chrome)/\(profile)/History")
            try sandbox.file("\(chrome)/\(profile)/Cookies")
            try sandbox.file("\(chrome)/\(profile)/GPUCache/data_0")
            try sandbox.file("\(chrome)/\(profile)/Service Worker/ScriptCache/index")
            try sandbox.file("\(chrome)/\(profile)/Service Worker/CacheStorage/abc/index")
            try sandbox.file("\(chrome)/\(profile)/IndexedDB/site/data")
        }
        try sandbox.file("\(chrome)/GrShaderCache/data_1")

        let finding = try #require(await AppDataScanner.webCaches(ScanContext(home: sandbox.root), minimumSize: 1))
        #expect(finding.aftermath == .rebuilds)
        #expect(finding.smart == .appJunk)
        let caches = try #require(finding.items.first { $0.title == "Chrome caches" })
        #expect(resolved(caches.paths) == resolved([
            sandbox.url("\(chrome)/GrShaderCache"),
            sandbox.url("\(chrome)/Default/GPUCache"), sandbox.url("\(chrome)/Profile 1/GPUCache"),
            sandbox.url("\(chrome)/Default/Service Worker/ScriptCache"), sandbox.url("\(chrome)/Profile 1/Service Worker/ScriptCache"),
        ]))
        #expect(caches.preselected == nil)
        let sites = try #require(finding.items.first { $0.title == "Chrome offline site data" })
        #expect(sites.preselected == false)
        #expect(sites.paths.count == 2)

        let everything = finding.items.flatMap(\.paths).map(\.lastPathComponent)
        for kept in ["History", "Cookies", "Preferences", "IndexedDB"] {
            #expect(!everything.contains(kept), "\(kept) is the user's, not a cache")
        }
        #expect([finding].smartSelection(SmartKind.standard).flatMap(\.paths).allSatisfy { !$0.path.contains("CacheStorage") })
    }

    @Test func offersAWebAppsCachesOnlyWhenItIsBuiltOnTheEngine() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let support = "Library/Application Support"
        try sandbox.file("\(support)/Slack/Local Storage/leveldb/000001.log")
        try sandbox.file("\(support)/Slack/Code Cache/js/abc")
        try sandbox.file("\(support)/Slack/Cache/Cache_Data/f_000001")
        try sandbox.file("\(support)/Slack/storage/messages.db")
        // A "Cache" folder of an app that is not built on the engine is the app's own business.
        try sandbox.file("\(support)/SomeEditor/Cache/projects.db")
        try sandbox.file("\(support)/SomeEditor/Code Cache/js/abc")
        // A web app whose plain "Cache" lacks the engine's layout keeps it.
        try sandbox.file("\(support)/Notes Plus/Local Storage/leveldb/000001.log")
        try sandbox.file("\(support)/Notes Plus/Cache/notes.json")
        // VS Code is the editor finding's to offer.
        try sandbox.file("\(support)/Code/Local Storage/leveldb/000001.log")
        try sandbox.file("\(support)/Code/Code Cache/js/abc")

        let finding = try #require(await AppDataScanner.webCaches(ScanContext(home: sandbox.root), minimumSize: 1))
        let paths = finding.items.flatMap(\.paths)
        #expect(resolved(paths) == resolved([sandbox.url("\(support)/Slack/Code Cache"), sandbox.url("\(support)/Slack/Cache")]))
        #expect(finding.items.first?.keptBy == "Slack")
    }

    @Test func everythingOfferedPassesTheGuard() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.file("\(chrome)/Default/Preferences")
        try sandbox.file("\(chrome)/Default/GPUCache/data_0")
        try sandbox.file("\(chrome)/OptGuideOnDeviceModel/weights.bin")
        try sandbox.file("Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/appstore/account-1/postbox/media/a")

        let context = ScanContext(home: sandbox.root)
        let findings = [await AppDataScanner.downloaded(context, minimumSize: 1), await AppDataScanner.webCaches(context, minimumSize: 1)]
            .compactMap { $0 }
        let safety = SafetyGuard(root: sandbox.root)
        #expect(!findings.isEmpty)
        for path in findings.flatMap(\.items).flatMap(\.paths) {
            #expect(safety.allows(path), "\(path.path) would be refused")
        }
    }
}
