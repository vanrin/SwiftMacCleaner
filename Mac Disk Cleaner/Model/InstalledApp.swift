//
//  InstalledApp.swift
//  Mac Disk Cleaner
//

import Foundation

/// What a file an app keeps is for, which is how the uninstaller groups an app's files.
nonisolated enum AppFileKind: Int, CaseIterable, Sendable, Comparable {
    case binaries, supportingFiles, caches, containers, preferences, logs, crashes, loginItems

    static func < (lhs: AppFileKind, rhs: AppFileKind) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .binaries: "Binaries"
        case .supportingFiles: "Supporting Files"
        case .caches: "Caches"
        case .containers: "Containers"
        case .preferences: "Preferences"
        case .logs: "Logs"
        case .crashes: "Crash Reports"
        case .loginItems: "Login Items"
        }
    }

    var symbol: String {
        switch self {
        case .binaries: "app"
        case .supportingFiles: "folder"
        case .caches: "archivebox"
        case .containers: "shippingbox"
        case .preferences: "slider.horizontal.3"
        case .logs: "doc.text"
        case .crashes: "exclamationmark.triangle"
        case .loginItems: "power"
        }
    }
}

/// One file or folder that belongs to an app: the app itself, or something it keeps in the Library.
nonisolated struct AppFile: Identifiable, Sendable, Hashable {
    var url: URL
    var kind: AppFileKind
    var size: Int64 = 0
    /// macOS would not let the app look inside, so `size` is 0 and the row says so instead of showing a number.
    var sizeUnknown = false

    var id: String { url.path }
}

/// Where an app was installed from.
nonisolated enum AppSource: String, CaseIterable, Sendable {
    case appStore, other

    var title: String {
        switch self {
        case .appStore: "App Store"
        case .other: "Other"
        }
    }
}

/// Who makes an app, for the handful of makers with enough apps to be worth a filter of their own.
nonisolated enum AppVendor: String, CaseIterable, Sendable {
    case apple, google, microsoft, jetBrains, adobe, other

    var title: String {
        switch self {
        case .apple: "Apple"
        case .google: "Google"
        case .microsoft: "Microsoft"
        case .jetBrains: "JetBrains"
        case .adobe: "Adobe"
        case .other: "Other"
        }
    }

    /// Read from the start of the bundle identifier, which a maker keeps the same across its apps.
    init(bundleID: String) {
        let id = bundleID.lowercased()
        let prefixes: [(String, AppVendor)] = [
            ("com.apple.", .apple), ("com.google.", .google), ("com.microsoft.", .microsoft),
            ("com.jetbrains.", .jetBrains), ("com.adobe.", .adobe),
        ]
        self = prefixes.first { id.hasPrefix($0.0) }?.1 ?? .other
    }
}

/// Where to ask which version of an app is current.
nonisolated enum UpdateFeed: Sendable, Hashable {
    /// The App Store's public catalogue, by bundle identifier.
    case appStore
    /// The Sparkle appcast the app names in its Info.plist.
    case sparkle(URL)
    /// The `latest-mac.yml` an Electron app's updater reads.
    case electron(URL)

    var title: String {
        switch self {
        case .appStore: "App Store"
        case .sparkle, .electron: "The app's own update feed"
        }
    }
}

/// An app in one of the Applications folders, with everything it keeps elsewhere.
nonisolated struct InstalledApp: Identifiable, Sendable, Hashable {
    static let unusedDays = 180.0

    var url: URL
    var name: String
    var bundleID: String
    /// The version people know it by, such as "12.9". Empty when the app does not say.
    var version = ""
    /// The build number, which is what an update feed compares.
    var build = ""
    var source = AppSource.other
    var vendor = AppVendor.other
    /// When it was last opened, going by Spotlight. Nil when it has not been opened since it was installed.
    var lastOpened: Date?
    /// When the bundle was last written, which is when it was installed or last updated.
    var installed: Date?
    /// The bundle belongs to another user, usually root, so only Finder can move it and macOS asks for a password.
    var needsPassword = false
    var feed: UpdateFeed?
    /// The app itself first, then what it keeps in the Library.
    var files: [AppFile] = []

    var id: String { url.path }
    var size: Int64 { files.reduce(0) { $0 + $1.size } }
    var bundleFile: AppFile? { files.first { $0.kind == .binaries } }

    /// Not opened for six months, or never opened and installed that long ago.
    func isUnused(asOf now: Date = Date()) -> Bool {
        guard let last = lastOpened ?? installed else { return false }
        return last < now.addingTimeInterval(-Self.unusedDays * 86_400)
    }

    /// The kinds of file this app has, in the order they are listed.
    var kinds: [AppFileKind] { Set(files.map(\.kind)).sorted() }

    func files(of kind: AppFileKind) -> [AppFile] { files.filter { $0.kind == kind } }
}

/// A newer version of an installed app, as its update feed describes it.
nonisolated struct AppUpdate: Identifiable, Sendable, Hashable {
    /// The app's id, so an update is found from its app and back.
    var id: String
    var installedVersion: String
    var newVersion: String
    var released: Date?
    /// The size of the download, when the feed gives it.
    var size: Int64?
    var notes: String?
    var feed: UpdateFeed
    /// The app's page in the App Store, where the update is installed.
    var storeURL: URL?
}
