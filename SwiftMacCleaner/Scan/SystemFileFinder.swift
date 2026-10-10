//
//  SystemFileFinder.swift
//  SwiftMacCleaner
//

import Foundation

/// A folder under /Library where an app's installer leaves something that runs for every user or as
/// root. Only root may change these folders, so nothing gets into one by accident.
nonisolated struct SystemFolder: Sendable, Hashable {
    enum Holds: Sendable, Hashable {
        /// Property lists launchd reads, for the agents or the daemons.
        case launchItems(BackgroundItem.Domain)
        /// The programs those property lists run as root.
        case helpers
    }

    var url: URL
    var holds: Holds

    static let standard: [SystemFolder] = [
        SystemFolder(url: URL(fileURLWithPath: "/Library/LaunchDaemons", isDirectory: true), holds: .launchItems(.systemDaemon)),
        SystemFolder(url: URL(fileURLWithPath: "/Library/LaunchAgents", isDirectory: true), holds: .launchItems(.systemAgent)),
        SystemFolder(url: URL(fileURLWithPath: "/Library/PrivilegedHelperTools", isDirectory: true), holds: .helpers),
    ]

    /// Whether root may be asked to move `url`: a plain file directly inside one of the folders, and
    /// not Apple's. A link, a folder or anything deeper is refused, so the script that runs as root
    /// only ever names files that root itself put there.
    ///
    /// This stands in for `SafetyGuard`, which keeps to the home folder and refuses all of these.
    static func allows(_ url: URL, in folders: [SystemFolder]) -> Bool {
        let target = url.standardizedFileURL
        let name = target.lastPathComponent
        let parent = target.deletingLastPathComponent().path
        guard !name.hasPrefix("."), !name.lowercased().hasPrefix("com.apple."),
              !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              folders.contains(where: { $0.url.standardizedFileURL.path == parent }) else { return false }
        var status = stat()
        return lstat(target.path, &status) == 0 && status.st_mode & S_IFMT == S_IFREG
    }
}

/// Works out which launch daemons, launch agents and privileged helpers under /Library belong to
/// which installed app. Reading is all it does.
///
/// These are what an uninstall must not leave behind: with the app gone they would still start at
/// every boot, some of them as root. Makers name them freely, so a name alone is not enough. An item
/// is an app's when one of these holds:
///
/// - it is named after the app's bundle identifier, or after an identifier that starts with it;
/// - the app's Info.plist lists it among the helpers the app may install (`SMPrivilegedExecutables`);
/// - its own property list names the app (`AssociatedBundleIdentifiers`);
/// - the program it runs sits inside the app's bundle;
/// - it is the program that one of the app's launch items runs.
///
/// An item more than one app has a claim on is shared, and is given to none of them.
nonisolated enum SystemFileFinder {
    /// The system-wide files of each app, keyed by the app's id and ordered by kind, then name.
    static func files(for apps: [AppIdentity], folders: [SystemFolder] = SystemFolder.standard) -> [String: [AppFile]] {
        guard !apps.isEmpty else { return [:] }
        let owners = AppFileFinder.Owners(apps)
        var found: [String: [AppFile]] = [:]
        /// The programs each app's launch items run, by path.
        var programs: [String: Set<String>] = [:]

        for folder in folders {
            guard case .launchItems(let domain) = folder.holds else { continue }
            for entry in entries(of: folder, among: folders) where entry.pathExtension == "plist" {
                guard let plist = Files.plist(at: entry), let service = AppFileFinder.launchService(in: plist, domain: domain),
                      !service.label.lowercased().hasPrefix("com.apple.") else { continue }
                let program = plist["Program"] as? String ?? (plist["ProgramArguments"] as? [String])?.first
                let associated = plist["AssociatedBundleIdentifiers"] as? [String]
                    ?? (plist["AssociatedBundleIdentifiers"] as? String).map { [$0] } ?? []
                let claimants = claimants(name: service.label, program: program, associated: associated, apps: apps, owners: owners)
                guard claimants.count == 1, let owner = claimants.first else { continue }
                found[owner, default: []].append(AppFile(url: entry, kind: .backgroundItems, service: service, isSystemWide: true))
                if let program {
                    programs[URL(fileURLWithPath: program).standardizedFileURL.path, default: []].insert(owner)
                }
            }
        }
        for folder in folders where folder.holds == .helpers {
            for entry in entries(of: folder, among: folders) {
                var claimants = claimants(name: entry.lastPathComponent, program: nil, associated: [], apps: apps, owners: owners)
                claimants.formUnion(programs[entry.standardizedFileURL.path] ?? [])
                guard claimants.count == 1, let owner = claimants.first else { continue }
                found[owner, default: []].append(AppFile(url: entry, kind: .helpers, isSystemWide: true))
            }
        }
        return found.mapValues { files in
            files.sorted { ($0.kind, $0.url.lastPathComponent) < ($1.kind, $1.url.lastPathComponent) }
        }
    }

    /// The apps with a claim on a service or a helper called `name`.
    static func claimants(name: String, program: String?, associated: [String], apps: [AppIdentity],
                          owners: AppFileFinder.Owners) -> Set<String> {
        let name = name.lowercased()
        let associated = Set(associated.map { $0.lowercased() })
        var claimants = Set<String>()
        if let owner = owners.owner(of: name, match: .identifier) { claimants.insert(owner) }
        for app in apps {
            if app.helpers.contains(where: { $0.lowercased() == name }) || associated.contains(app.bundleID.lowercased())
                || program?.hasPrefix(app.id + "/") == true {
                claimants.insert(app.id)
            }
        }
        return claimants
    }

    /// The files in a folder that root may be asked to move, in name order.
    private static func entries(of folder: SystemFolder, among folders: [SystemFolder]) -> [URL] {
        Files.children(of: folder.url)
            .filter { SystemFolder.allows($0, in: folders) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}
