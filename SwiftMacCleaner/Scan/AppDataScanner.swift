//
//  AppDataScanner.swift
//  SwiftMacCleaner
//
//  What apps keep outside ~/Library/Caches and fill up on their own: the media a chat app keeps
//  after you have seen it, the AI model a browser downloads for itself, and the caches browsers and
//  apps built on the same engine keep in Application Support.
//

import Foundation

nonisolated enum AppDataScanner {
    static let downloadedFindingID = "caches.downloaded"
    static let webFindingID = "caches.web"

    /// A browser built on Chromium, and where it keeps its profiles.
    struct Browser: Sendable {
        var name: String
        var bundleID: String
        /// Relative to home.
        var root: String
    }

    static let browsers: [Browser] = [
        Browser(name: "Chrome", bundleID: "com.google.Chrome", root: "Library/Application Support/Google/Chrome"),
        Browser(name: "Chrome Beta", bundleID: "com.google.Chrome.beta", root: "Library/Application Support/Google/Chrome Beta"),
        Browser(name: "Chrome Canary", bundleID: "com.google.Chrome.canary", root: "Library/Application Support/Google/Chrome Canary"),
        Browser(name: "Chromium", bundleID: "org.chromium.Chromium", root: "Library/Application Support/Chromium"),
        Browser(name: "Brave", bundleID: "com.brave.Browser", root: "Library/Application Support/BraveSoftware/Brave-Browser"),
        Browser(name: "Edge", bundleID: "com.microsoft.edgemac", root: "Library/Application Support/Microsoft Edge"),
        Browser(name: "Vivaldi", bundleID: "com.vivaldi.Vivaldi", root: "Library/Application Support/Vivaldi"),
        Browser(name: "Arc", bundleID: "company.thebrowser.Browser", root: "Library/Application Support/Arc/User Data"),
        Browser(name: "Opera", bundleID: "com.operasoftware.Opera", root: "Library/Application Support/com.operasoftware.Opera"),
    ]

    /// Caches inside a browser profile or an app's folder that the engine rebuilds as it runs.
    static let engineCaches = [
        "Code Cache", "GPUCache", "DawnCache", "DawnGraphiteCache", "DawnWebGPUCache", "Service Worker/ScriptCache",
    ]
    /// Shader caches a browser keeps once for all its profiles.
    static let browserCaches = ["GrShaderCache", "ShaderCache", "GraphiteDawnCache"]
    /// What sites store for themselves to work offline. Chrome files it under site data, not cache.
    static let siteCache = "Service Worker/CacheStorage"
    /// The model Chrome downloads for its built-in AI features.
    static let browserModel = "OptGuideOnDeviceModel"
    /// Application Support folders other parts of the scan already look inside.
    static let claimedSupportFolders: Set<String> = [
        "Code", "Cursor", "Windsurf", "Google", "BraveSoftware", "Microsoft Edge", "Chromium", "Vivaldi", "Arc",
        "com.operasoftware.Opera", "JetBrains",
    ]

    static func findings(_ context: ScanContext) async -> [Finding] {
        var findings: [Finding] = []
        if let finding = await downloaded(context) { findings.append(finding) }
        if let finding = await webCaches(context) { findings.append(finding) }
        return findings
    }

    // MARK: Downloaded again

    /// Telegram's media and Chrome's model: large, fetched again when needed, never ticked.
    static func downloaded(_ context: ScanContext, minimumSize: Int64 = 100_000_000) async -> Finding? {
        var rows: [PathGroup] = []
        for media in telegramMedia(home: context.home) {
            rows.append(PathGroup(id: "telegram/\(media.path)", title: "Telegram media",
                            detail: "Photos, videos and files from your chats. Telegram downloads them again when you open them, except media from secret chats",
                            paths: [media], keptBy: "ru.keepcoder.Telegram"))
        }
        let desktop = context.home.appending(path: "Library/Application Support/Telegram Desktop/tdata")
        for folder in Files.subdirectories(of: desktop) where folder.lastPathComponent.hasPrefix("user_data") {
            rows.append(PathGroup(id: "telegramDesktop/\(folder.path)", title: "Telegram Desktop media",
                            detail: "Media and files Telegram Desktop keeps after you view them. It downloads them again when you open them",
                            paths: [folder], keptBy: "com.tdesktop.Telegram"))
        }
        for browser in browsers {
            let model = context.home.appending(path: browser.root).appending(path: browserModel)
            guard Files.isDirectory(model) else { continue }
            rows.append(PathGroup(id: "model/\(model.path)", title: "\(browser.name) on-device AI model",
                            detail: "\(browser.name) downloads it again for its built-in AI features, unless you turn on-device AI off in its System settings",
                            paths: [model], keptBy: browser.bundleID))
        }
        let items = await Sizing.items(prefix: downloadedFindingID, from: rows, minimumSize: minimumSize)
        guard !items.isEmpty else { return nil }
        return Finding(
            id: downloadedFindingID,
            area: .cachesLogs,
            aftermath: .downloadsAgain,
            title: "Chat media and app downloads",
            summary: items.prefix(3).map(\.title).joined(separator: ", ") + (items.count > 3 ? " and more" : ""),
            explanation: "Media a chat app keeps after you have seen it, and models apps download for themselves. Each comes back from the app's servers when it is needed, so they go to the Trash and nothing here is ticked for you. Each waits until its app has quit.",
            method: .trash,
            actionTarget: CatalogScanner.eachRowTarget,
            items: items
        )
    }

    /// Every account's media folder: `<group container>/<channel>/account-<id>/postbox/media`.
    /// The App Store copy keeps its accounts under `appstore`, the copy from telegram.org under `stable`.
    static func telegramMedia(home: URL) -> [URL] {
        let container = home.appending(path: "Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram")
        return Files.subdirectories(of: container).flatMap { channel in
            Files.subdirectories(of: channel)
                .filter { $0.lastPathComponent.hasPrefix("account-") }
                .map { $0.appending(path: "postbox/media") }
                .filter(Files.isDirectory)
        }
    }

    // MARK: Browser and web app caches

    static func webCaches(_ context: ScanContext, minimumSize: Int64 = 10_000_000) async -> Finding? {
        var rows: [PathGroup] = []
        for browser in browsers {
            let root = context.home.appending(path: browser.root)
            guard Files.isDirectory(root) else { continue }
            let profiles = profiles(in: root)
            let caches = browserCaches.map { root.appending(path: $0) }
                + profiles.flatMap { profile in (engineCaches + ["Cache"]).map { profile.appending(path: $0) } }
            rows.append(PathGroup(id: "browser/\(browser.root)", title: "\(browser.name) caches",
                            detail: "Compiled scripts and graphics shaders, for \(profiles.count == 1 ? "1 profile" : "\(profiles.count) profiles"). Rebuilt as you browse",
                            paths: caches.filter(Files.isDirectory), keptBy: browser.bundleID))
            rows.append(PathGroup(id: "sites/\(browser.root)", title: "\(browser.name) offline site data",
                            detail: "Copies sites keep to load faster and work offline. They fill up again as you visit, and some sites need a connection the first time",
                            paths: profiles.map { $0.appending(path: siteCache) }.filter(Files.isDirectory),
                            preselected: false, keptBy: browser.bundleID))
        }

        let support = context.home.appending(path: "Library/Application Support")
        let ownName = Bundle.main.bundleIdentifier ?? ""
        for folder in Files.subdirectories(of: support) {
            let name = folder.lastPathComponent
            guard !claimedSupportFolders.contains(name), name != ownName, isWebApp(folder) else { continue }
            var caches = engineCaches.map { folder.appending(path: $0) }
            // A plain "Cache" counts only when it has the engine's own layout inside.
            if Files.isDirectory(folder.appending(path: "Cache/Cache_Data")) { caches.append(folder.appending(path: "Cache")) }
            rows.append(PathGroup(id: "app/\(name)", title: CachesLogsScanner.displayName(name),
                            detail: "Web content, compiled scripts and shaders in ~/Library/Application Support/\(name)",
                            paths: caches.filter(Files.isDirectory), keptBy: name))
        }

        let items = await Sizing.items(prefix: webFindingID, from: rows, minimumSize: minimumSize)
        guard !items.isEmpty else { return nil }
        return Finding(
            id: webFindingID,
            area: .cachesLogs,
            aftermath: .rebuilds,
            title: "Browser and web app caches",
            summary: "\(items.count) \(items.count == 1 ? "cache" : "caches") in \(context.tilde(support))",
            explanation: "Caches Chrome, Brave, Edge and apps built on the same engine keep beside their settings: compiled scripts, graphics shaders and web content. Each rebuilds as it runs. History, logins, cookies and settings are left alone, and offline site data is not ticked for you.",
            method: .delete,
            actionTarget: CatalogScanner.eachRowTarget,
            items: items,
            keepsChanging: true
        )
    }

    /// The browser's profile folders: "Default", "Profile 1" and the rest, each with its Preferences file.
    /// Some browsers keep their one profile in the root itself.
    static func profiles(in root: URL) -> [URL] {
        let profiles = Files.subdirectories(of: root).filter { Files.exists($0.appending(path: "Preferences")) }
        guard profiles.isEmpty, Files.exists(root.appending(path: "Preferences")) else { return profiles }
        return [root]
    }

    /// Whether a folder belongs to an app built on Chromium, such as one made with Electron.
    static func isWebApp(_ folder: URL) -> Bool {
        Files.isDirectory(folder.appending(path: "Local Storage/leveldb"))
    }
}
