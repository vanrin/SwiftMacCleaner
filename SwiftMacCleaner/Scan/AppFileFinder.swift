//
//  AppFileFinder.swift
//  SwiftMacCleaner
//

import Foundation

/// Works out which items in the user's Library belong to which installed app.
///
/// An item is only ever given to one app. It counts as an app's when it is named after the app's
/// bundle identifier, or after an identifier that starts with it (helpers and extensions), or after the
/// app's own name. Where two apps could claim the same item, the longer identifier wins, and a name or
/// a shared container that more than one app answers to is given to none of them.
///
/// Some makers keep one folder for all their apps, such as `Application Support/Google/Chrome`. Inside a
/// folder named after an app's maker, a folder named after that app is the app's as well.
nonisolated enum AppFileFinder {
    enum Match: Sendable {
        /// Named after the bundle identifier.
        case identifier
        /// Named after the bundle identifier or after the app.
        case identifierOrName
        /// A crash report, which starts with the name of the program that crashed.
        case crashReport
        /// A shared container, named in the app's signature.
        case group
    }

    struct Place: Sendable {
        /// Relative to home.
        var path: String
        var kind: AppFileKind
        var match: Match
    }

    static let places: [Place] = [
        Place(path: "Library/Application Support", kind: .supportingFiles, match: .identifierOrName),
        Place(path: "Library/Saved Application State", kind: .supportingFiles, match: .identifier),
        Place(path: "Library/Application Scripts", kind: .supportingFiles, match: .identifier),
        Place(path: "Library/Caches", kind: .caches, match: .identifierOrName),
        Place(path: "Library/HTTPStorages", kind: .caches, match: .identifier),
        Place(path: "Library/WebKit", kind: .caches, match: .identifier),
        Place(path: "Library/Containers", kind: .containers, match: .identifier),
        Place(path: "Library/Group Containers", kind: .containers, match: .group),
        Place(path: "Library/Preferences", kind: .preferences, match: .identifier),
        Place(path: "Library/Preferences/ByHost", kind: .preferences, match: .identifier),
        Place(path: "Library/Logs", kind: .logs, match: .identifierOrName),
        Place(path: "Library/Logs/DiagnosticReports", kind: .crashes, match: .crashReport),
        Place(path: "Library/LaunchAgents", kind: .loginItems, match: .identifier),
    ]

    /// Endings that come after the identifier in a file name.
    static let identifierSuffixes = [".plist", ".savedState", ".binarycookies"]
    static let crashSuffixes = [".ips", ".crash", ".diag", ".hang", ".spin"]
    /// Folders a maker shares between its apps. An app that happens to carry the maker's name does not own them.
    static let sharedNames: Set<String> = ["google", "microsoft", "adobe", "jetbrains", "apple", "mozilla"]

    /// The Library items of each app, keyed by the app's id and ordered by kind, then name.
    /// Anything the guard would refuse to remove is left out, so nothing is listed that could not be acted on.
    static func files(for apps: [AppIdentity], home: URL, safety: SafetyGuard) -> [String: [AppFile]] {
        let owners = Owners(apps)
        var found: [String: [AppFile]] = [:]
        for place in places {
            for entry in Files.children(of: home.appending(path: place.path)) {
                var name = entry.lastPathComponent
                // An iPhone app's container is named with a random identifier, and says inside whose it is.
                if place.kind == .containers, UUID(uuidString: name) != nil {
                    name = containerIdentifier(of: entry) ?? name
                }
                guard !name.hasPrefix("."), let owner = owners.owner(of: name, match: place.match),
                      safety.allows(entry) else { continue }
                found[owner, default: []].append(AppFile(url: entry, kind: place.kind))
            }
        }
        for (owner, file) in nestedFiles(for: apps, home: home, claimed: Set(found.values.joined().map(\.url)))
        where safety.allows(file.url) {
            found[owner, default: []].append(file)
        }
        return found.mapValues { files in
            files.sorted { ($0.kind, $0.url.lastPathComponent) < ($1.kind, $1.url.lastPathComponent) }
        }
    }

    // MARK: Folders inside a maker's folder

    /// A name with everything but its letters and digits dropped, so "Brave-Browser" meets "Brave Browser".
    static func normalized(_ name: String) -> String {
        String(name.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    /// The maker's part of a bundle identifier: "google" in "com.google.Chrome". Nil when it is too short
    /// to tell makers apart, or is Apple, whose folders are macOS's own.
    static func makerKey(of bundleID: String) -> String? {
        let parts = bundleID.split(separator: ".")
        guard parts.count >= 3 else { return nil }
        let maker = normalized(String(parts[1]))
        return maker.count >= 4 && maker != "apple" ? maker : nil
    }

    /// What a folder inside the maker's folder may be called for it to be this app's: the app's names,
    /// the same without the maker in front, and the last part of its identifier.
    static func productKeys(of app: AppIdentity, maker: String) -> Set<String> {
        var keys = Set(app.names.map(normalized))
        keys.formUnion(keys.filter { $0.hasPrefix(maker) }.map { String($0.dropFirst(maker.count)) })
        if let last = app.bundleID.split(separator: ".").last { keys.insert(normalized(String(last))) }
        return keys.filter { $0.count >= 3 }
    }

    /// Whether a folder's name is one of the keys, alone or followed by a version: "IntelliJIdea2025.3".
    static func isProduct(_ folder: String, of keys: Set<String>) -> Bool {
        let name = normalized(folder)
        return keys.contains { key in
            guard name.hasPrefix(key) else { return false }
            let rest = name.dropFirst(key.count)
            return rest.isEmpty || rest.allSatisfy(\.isNumber)
        }
    }

    /// Folders that sit inside a folder named after an app's maker and are named after the app itself.
    /// One that two apps could claim is given to neither.
    static func nestedFiles(for apps: [AppIdentity], home: URL, claimed: Set<URL>) -> [(owner: String, file: AppFile)] {
        let candidates = apps.compactMap { app -> (id: String, maker: String, keys: Set<String>)? in
            guard let maker = makerKey(of: app.bundleID) else { return nil }
            return (app.id, maker, productKeys(of: app, maker: maker))
        }
        guard !candidates.isEmpty else { return [] }
        var found: [(owner: String, file: AppFile)] = []
        for place in places where place.match == .identifierOrName {
            for folder in Files.subdirectories(of: home.appending(path: place.path)) where !claimed.contains(folder) {
                let name = normalized(folder.lastPathComponent)
                let makers = candidates.filter { name.hasPrefix($0.maker) }
                guard !makers.isEmpty else { continue }
                for entry in Files.subdirectories(of: folder) {
                    let owners = makers.filter { isProduct(entry.lastPathComponent, of: $0.keys) }
                    if owners.count == 1 { found.append((owners[0].id, AppFile(url: entry, kind: place.kind))) }
                }
            }
        }
        return found
    }

    /// The bundle identifier macOS recorded for a container. Nil when macOS will not let the app read it.
    static func containerIdentifier(of container: URL) -> String? {
        Files.plist(at: container.appending(path: ".com.apple.containermanagerd.metadata.plist"))?["MCMMetadataIdentifier"] as? String
    }

    /// Who owns what, worked out once for all the installed apps.
    struct Owners: Sendable {
        /// Lowercased identifiers with their app, longest first, so the most specific one is tried first.
        private var identifiers: [(identifier: String, app: String)] = []
        /// Names, program names and shared containers that exactly one app answers to.
        private var names: [String: String] = [:]
        private var executables: [(name: String, app: String)] = []
        private var groups: [String: String] = [:]

        init(_ apps: [AppIdentity]) {
            identifiers = apps.map { ($0.bundleID.lowercased(), $0.id) }.sorted { $0.identifier.count > $1.identifier.count }
            names = Self.unique(apps.flatMap { app in app.names.map { ($0, app.id) } })
            groups = Self.unique(apps.flatMap { app in app.groups.map { ($0.lowercased(), app.id) } })
            executables = Self.unique(apps.filter { !$0.executable.isEmpty }.map { ($0.executable.lowercased(), $0.id) })
                .map { ($0.key, $0.value) }.sorted { $0.name.count > $1.name.count }
        }

        /// Keeps the keys that only one app has.
        private static func unique(_ pairs: [(String, String)]) -> [String: String] {
            var owners: [String: Set<String>] = [:]
            for (key, app) in pairs { owners[key, default: []].insert(app) }
            return owners.compactMapValues { $0.count == 1 ? $0.first : nil }
        }

        func owner(of name: String, match: Match) -> String? {
            let lower = name.lowercased()
            switch match {
            case .identifier:
                return identifierOwner(of: lower)
            case .identifierOrName:
                return identifierOwner(of: lower) ?? nameOwner(of: lower)
            case .group:
                return groups[lower]
            case .crashReport:
                guard AppFileFinder.crashSuffixes.contains(where: lower.hasSuffix) else { return nil }
                // "Name-2026-10-08-101500.ips" and the older "Name_2026-10-08-101500_Mac.crash".
                return executables.first { lower.hasPrefix($0.name + "-20") || lower.hasPrefix($0.name + "_20") }?.app
            }
        }

        private func identifierOwner(of lower: String) -> String? {
            var key = lower
            for suffix in AppFileFinder.identifierSuffixes where key.hasSuffix(suffix.lowercased()) {
                key = String(key.dropLast(suffix.count))
            }
            return identifiers.first { candidate in
                if key == candidate.identifier { return true }
                // "com.maker" alone is too short to claim everything that starts with it.
                return candidate.identifier.split(separator: ".").count >= 3 && key.hasPrefix(candidate.identifier + ".")
            }?.app
        }

        private func nameOwner(of lower: String) -> String? {
            guard lower.count >= 3, !AppFileFinder.sharedNames.contains(lower) else { return nil }
            return names[lower]
        }
    }
}
