//
//  AppScanner.swift
//  SwiftMacCleaner
//

import CoreServices
import Foundation
import Security

/// How far a look at the installed apps has got.
nonisolated struct AppScanProgress: Sendable, Equatable {
    var done = 0
    var total = 0
    /// The app being measured.
    var name = ""
    /// The apps are measured and their update feeds are being asked.
    var isCheckingUpdates = false

    var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }
}

/// What tells one app's files from another's: its identifier, the names it goes by, and what it was signed with.
nonisolated struct AppIdentity: Sendable {
    /// The app's id, which is the path of its bundle.
    var id: String
    var bundleID: String
    /// Every name the app goes by: its file name, and the names in its Info.plist.
    var names: Set<String>
    /// The name of the program inside the bundle, which crash reports are filed under.
    var executable: String
    /// The shared containers its signature entitles it to.
    var groups: [String]
    /// The privileged helpers its Info.plist says it may install, by the name launchd knows each one by.
    var helpers: [String] = []
}

/// Lists the apps in the Applications folders with what each one keeps in the Library, and what its
/// installer left under /Library. It only reads.
nonisolated enum AppScanner {
    static func applicationRoots(home: URL) -> [URL] {
        [URL(fileURLWithPath: "/Applications", isDirectory: true), home.appending(path: "Applications")]
    }

    /// App bundles directly inside the roots and one folder down, such as /Applications/Utilities.
    /// A link to an app is left out: the app it points at is not in these folders.
    static func bundles(in roots: [URL]) -> [URL] {
        var bundles: [URL] = []
        for root in roots {
            for entry in Files.children(of: root) where !Files.isSymlink(entry) {
                if entry.pathExtension == "app" {
                    bundles.append(entry)
                } else if Files.isDirectory(entry) {
                    bundles += Files.children(of: entry).filter { $0.pathExtension == "app" && !Files.isSymlink($0) }
                }
            }
        }
        return bundles
    }

    /// Reads one bundle. Nil for anything that is not an app the user could remove: no identifier,
    /// part of macOS, or this app itself.
    static func describe(_ bundle: URL, ownBundleID: String = Bundle.main.bundleIdentifier ?? "") -> (app: InstalledApp, identity: AppIdentity)? {
        // An iPhone or iPad app from the App Store is a wrapper around the real bundle.
        let wrapped = bundle.appending(path: "WrappedBundle")
        let isWrapped = !Files.exists(bundle.appending(path: "Contents/Info.plist")) && Files.exists(wrapped)
        let inner = isWrapped ? wrapped.resolvingSymlinksInPath() : bundle
        guard let info = Files.plist(at: inner.appending(path: isWrapped ? "Info.plist" : "Contents/Info.plist")),
              let bundleID = info["CFBundleIdentifier"] as? String, !bundleID.isEmpty, bundleID != ownBundleID,
              !isProtectedBySystem(bundle) else { return nil }
        let fileName = bundle.deletingPathExtension().lastPathComponent
        let isStoreApp = isWrapped || Files.exists(bundle.appending(path: "Contents/_MASReceipt/receipt"))
        let signature = signature(of: inner)

        let app = InstalledApp(
            url: bundle,
            name: fileName,
            bundleID: bundleID,
            version: info["CFBundleShortVersionString"] as? String ?? "",
            build: info["CFBundleVersion"] as? String ?? "",
            source: isStoreApp ? .appStore : .other,
            vendor: AppVendor(bundleID: bundleID),
            lastOpened: lastOpened(bundle),
            installed: Files.modificationDate(bundle),
            needsPassword: belongsToAnotherUser(bundle),
            // The App Store's catalogue of Mac apps does not list the iPhone apps, so those are not asked about.
            feed: isWrapped ? nil : feed(for: bundle, info: info, isStoreApp: isStoreApp)
        )
        let names = [fileName, info["CFBundleName"] as? String, info["CFBundleDisplayName"] as? String]
            .compactMap { $0?.lowercased() }.filter { !$0.isEmpty }
        let identity = AppIdentity(
            id: app.id, bundleID: bundleID, names: Set(names),
            executable: info["CFBundleExecutable"] as? String ?? "", groups: signature.groups,
            helpers: (info["SMPrivilegedExecutables"] as? [String: Any]).map { Array($0.keys) } ?? []
        )
        return (app, identity)
    }

    /// Apps macOS itself guards, such as Safari, which nothing may move.
    static func isProtectedBySystem(_ bundle: URL) -> Bool {
        if bundle.path.hasPrefix("/System/") { return true }
        var status = stat()
        guard lstat(bundle.path, &status) == 0 else { return true }
        return status.st_flags & UInt32(SF_RESTRICTED) != 0
    }

    /// An app installed by the App Store or by a package belongs to root. Finder asks for a password to move it.
    static func belongsToAnotherUser(_ bundle: URL) -> Bool {
        var status = stat()
        guard lstat(bundle.path, &status) == 0 else { return false }
        return status.st_uid != getuid()
    }

    /// When the app was last opened, which Spotlight keeps track of. Nil when it never was.
    static func lastOpened(_ bundle: URL) -> Date? {
        guard let item = MDItemCreateWithURL(nil, bundle as CFURL) else { return nil }
        return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
    }

    /// The shared containers the app's signature names. Reading the signature does not check it.
    static func signature(of bundle: URL) -> (team: String?, groups: [String]) {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundle as CFURL, [], &code) == errSecSuccess, let code else { return (nil, []) }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let details = information as? [String: Any] else { return (nil, []) }
        let entitlements = details[kSecCodeInfoEntitlementsDict as String] as? [String: Any]
        return (
            details[kSecCodeInfoTeamIdentifier as String] as? String,
            entitlements?["com.apple.security.application-groups"] as? [String] ?? []
        )
    }

    /// A folder macOS keeps private, such as another app's container when Full Disk Access is off.
    static func isUnreadable(_ url: URL) -> Bool {
        guard Files.isDirectory(url), !Files.isSymlink(url) else { return false }
        do {
            _ = try FileManager.default.contentsOfDirectory(atPath: url.path)
            return false
        } catch {
            return Files.isPermissionError(error)
        }
    }

    // MARK: Update feeds

    static func feed(for bundle: URL, info: [String: Any], isStoreApp: Bool) -> UpdateFeed? {
        if isStoreApp { return .appStore }
        if let text = info["SUFeedURL"] as? String, let url = URL(string: text), url.scheme == "https" {
            return .sparkle(url)
        }
        let config = bundle.appending(path: "Contents/Resources/app-update.yml")
        guard let text = try? String(contentsOf: config, encoding: .utf8) else { return nil }
        return electronFeed(fromUpdaterConfig: text).map(UpdateFeed.electron)
    }

    /// Where an Electron app's updater looks, read from its `app-update.yml`. Only the two kinds of
    /// provider that publish a plain file are understood.
    static func electronFeed(fromUpdaterConfig text: String) -> URL? {
        var values: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
            values[key] = value
        }
        switch values["provider"] {
        case "generic":
            guard let base = values["url"], let url = URL(string: base), url.scheme == "https" else { return nil }
            return url.appending(path: "latest-mac.yml")
        case "github":
            guard let owner = values["owner"], let repo = values["repo"], !owner.isEmpty, !repo.isEmpty else { return nil }
            return URL(string: "https://github.com/\(owner)/\(repo)/releases/latest/download/latest-mac.yml")
        default:
            return nil
        }
    }

    // MARK: Scanning

    /// Every app in the roots, each with its files measured. Stopping early returns the apps measured so far.
    @concurrent
    static func scan(home: URL, roots: [URL]? = nil, safety: SafetyGuard, systemFolders: [SystemFolder] = SystemFolder.standard,
                     caskrooms: [URL] = HomebrewCasks.caskrooms(),
                     progress: @escaping @Sendable (AppScanProgress) -> Void) async -> [InstalledApp] {
        let described = bundles(in: roots ?? applicationRoots(home: home)).compactMap { describe($0) }
        let casks = Dictionary(HomebrewCasks.installed(in: caskrooms).map { ($0.app.standardizedFileURL.path, $0) }) { first, _ in first }
        var related = AppFileFinder.files(for: described.map(\.identity), home: home, safety: safety)
        for (owner, files) in SystemFileFinder.files(for: described.map(\.identity), folders: systemFolders) {
            related[owner, default: []] += files.filter { !safety.isOnNeverSuggest($0.url.resolvingSymlinksInPath().path) }
        }

        var apps: [InstalledApp] = []
        for (index, entry) in described.enumerated() {
            if Task.isCancelled { break }
            var app = entry.app
            app.cask = casks[app.url.resolvingSymlinksInPath().standardizedFileURL.path]
            progress(AppScanProgress(done: index, total: described.count, name: app.name))
            let files = related[app.id] ?? []
            let sizes = await Sizing.sizes(of: [app.url] + files.map(\.url))
            app.files = [AppFile(url: app.url, kind: .binaries, size: sizes[app.url] ?? 0)] + files.map { file in
                var file = file
                file.size = sizes[file.url] ?? 0
                file.sizeUnknown = file.size == 0 && isUnreadable(file.url)
                return file
            }
            apps.append(app)
        }
        return apps
    }
}
