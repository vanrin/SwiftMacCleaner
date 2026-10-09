//
//  BackgroundItemScanner.swift
//  SwiftMacCleaner
//

import CoreServices
import Foundation

/// A launch agent or daemon another maker installed: something launchd starts on its own, at login
/// or at boot, whether or not the app it came with is open.
nonisolated struct BackgroundItem: Identifiable, Sendable, Hashable {
    enum Domain: String, Sendable, CaseIterable {
        /// `~/Library/LaunchAgents`: runs as this user, from login.
        case userAgent
        /// `/Library/LaunchAgents`: runs as whoever logs in.
        case systemAgent
        /// `/Library/LaunchDaemons`: runs as root, from boot.
        case systemDaemon

        var title: String {
            switch self {
            case .userAgent: "Launch agent"
            case .systemAgent: "Launch agent for every user"
            case .systemDaemon: "Launch daemon"
            }
        }

        var folder: String {
            switch self {
            case .userAgent: "~/Library/LaunchAgents"
            case .systemAgent: "/Library/LaunchAgents"
            case .systemDaemon: "/Library/LaunchDaemons"
            }
        }

        var runsAsRoot: Bool { self == .systemDaemon }

        /// Its plist belongs to root, so unloading it and moving the plist need the password.
        var needsPassword: Bool { self != .userAgent }

        /// Where launchd keeps the service loaded.
        func launchdDomain(uid: uid_t) -> String { self == .systemDaemon ? "system" : "gui/\(uid)" }
    }

    var plist: URL
    var label: String
    var domain: Domain
    /// The program it runs.
    var program: String? = nil
    /// The app it belongs to, when the program sits inside one or the plist names one.
    var appName: String? = nil
    var appURL: URL? = nil
    var runsAtLoad = false
    var keepsAlive = false
    var interval: TimeInterval? = nil
    var hasCalendar = false
    /// Starts when a file it names changes, or when a folder it names gets something in it.
    var watchesPaths = false
    var watchesFolders = false
    /// Switched off in its own plist, so launchd leaves it alone until its maker turns it on again.
    var isDisabled = false
    /// Whether launchd has it loaded. Nil when launchd could not be asked.
    var isLoaded: Bool? = nil
    var isRunning = false

    var id: String { plist.path }
    var title: String { appName ?? label }
    var needsPassword: Bool { domain.needsPassword }

    /// When launchd starts it.
    var schedule: String {
        var parts: [String] = []
        if runsAtLoad { parts.append(domain == .systemDaemon ? "starts at boot" : "starts at login") }
        if let interval {
            let minutes = Int(interval / 60)
            parts.append(minutes >= 120 ? "every \(minutes / 60) hours" : minutes >= 1 ? "every \(minutes) minutes" : "every \(Int(interval)) seconds")
        }
        if hasCalendar { parts.append("on a schedule") }
        if watchesPaths { parts.append("when a watched file changes") }
        if watchesFolders { parts.append("when a watched folder fills") }
        if keepsAlive { parts.append("kept running") }
        if parts.isEmpty { parts.append("on demand") }
        return parts.joined(separator: ", ")
    }

    /// What launchd makes of it right now.
    var state: String {
        if isRunning { return "running now" }
        if isDisabled { return "disabled" }
        switch isLoaded {
        case true: return "loaded"
        case false: return "not loaded"
        case nil: return "state unknown"
        }
    }

    /// "Launch daemon · starts at boot · running now · com.docker.vmnetd"
    var detail: String {
        var parts = [domain.runsAsRoot ? "\(domain.title), runs as root" : domain.title, schedule, state]
        if appName != nil { parts.append(label) }
        return parts.joined(separator: " · ")
    }
}

nonisolated struct BackgroundScan: Sendable {
    var items: [BackgroundItem] = []
    /// What could not be read on the way, as sentences for the user: a folder macOS kept private, a
    /// plist that is not one, or launchd not answering.
    var issues: [String] = []
}

/// Lists the launch agents and daemons in the three folders other makers install into. Apple's own,
/// and this app's, are left out. Reading is all it does.
nonisolated enum BackgroundItemScanner {
    struct Folder: Sendable, Hashable {
        var url: URL
        var domain: BackgroundItem.Domain
    }

    /// What launchd has loaded, by label, with the process id of anything running.
    struct Loaded: Sendable, Hashable {
        var user: [String: Int?] = [:]
        var system: [String: Int?] = [:]
        /// False when launchd could not be asked, in which case nothing is known.
        var asked = false

        func status(of label: String, in domain: BackgroundItem.Domain) -> (isLoaded: Bool?, pid: Int?) {
            guard asked else { return (nil, nil) }
            let table = domain == .systemDaemon ? system : user
            guard let entry = table[label] else { return (false, nil) }
            return (true, entry)
        }
    }

    static func folders(home: URL) -> [Folder] {
        [
            Folder(url: home.appending(path: "Library/LaunchAgents"), domain: .userAgent),
            Folder(url: URL(fileURLWithPath: "/Library/LaunchAgents", isDirectory: true), domain: .systemAgent),
            Folder(url: URL(fileURLWithPath: "/Library/LaunchDaemons", isDirectory: true), domain: .systemDaemon),
        ]
    }

    /// The items, user agents first, each folder's in name order, with whatever could not be read.
    @concurrent
    static func scan(
        home: URL, ownBundleID: String, folders: [Folder]? = nil, loaded: Loaded? = nil,
        appLookup: @Sendable (String) -> URL? = installedApp(withBundleID:)
    ) async -> BackgroundScan {
        let loaded = loaded ?? Self.loaded()
        var scan = BackgroundScan()
        if !loaded.asked {
            scan.issues.append("launchd could not be asked which items are loaded, so each item's state is unknown.")
        }
        for folder in folders ?? Self.folders(home: home) {
            let names: [String]
            do {
                names = try FileManager.default.contentsOfDirectory(atPath: folder.url.path)
            } catch {
                // A folder that is not there holds nothing; any other refusal is worth telling.
                if (error as NSError).code != NSFileReadNoSuchFileError, (error as NSError).code != Int(ENOENT) {
                    scan.issues.append("\(displayPath(folder.url, home: home)) could not be read: \(error.localizedDescription)")
                }
                continue
            }
            let plists = names
                .filter { $0.hasSuffix(".plist") }
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                .map { folder.url.appending(path: $0) }
                .filter { !Files.isSymlink($0) }
            for url in plists {
                guard let plist = Files.plist(at: url) else {
                    scan.issues.append("\(url.lastPathComponent) in \(displayPath(folder.url, home: home)) is not a property list launchd could read.")
                    continue
                }
                guard var item = item(from: plist, at: url, domain: folder.domain, appLookup: appLookup) else {
                    scan.issues.append("\(url.lastPathComponent) in \(displayPath(folder.url, home: home)) names no service, so launchd ignores it.")
                    continue
                }
                guard !isApple(item), !item.label.hasPrefix(ownBundleID) else { continue }
                let status = loaded.status(of: item.label, in: folder.domain)
                item.isLoaded = status.isLoaded
                item.isRunning = status.pid != nil
                scan.items.append(item)
            }
        }
        return scan
    }

    /// The path with the home folder written as `~`.
    static func displayPath(_ url: URL, home: URL) -> String {
        let path = url.path
        let homePath = home.path
        guard path == homePath || path.hasPrefix(homePath + "/") else { return path }
        return "~" + path.dropFirst(homePath.count)
    }

    /// Where Launch Services says an app with this identifier is, when one is installed.
    static func installedApp(withBundleID bundleID: String) -> URL? {
        guard let urls = LSCopyApplicationURLsForBundleIdentifier(bundleID as CFString, nil)?.takeRetainedValue() as? [URL] else {
            return nil
        }
        return urls.first
    }

    /// Apple's own services, which are never offered, however they are named.
    static func isApple(_ item: BackgroundItem) -> Bool {
        item.label.hasPrefix("com.apple.") || item.program?.hasPrefix("/System/") == true
    }

    /// One plist read into an item. Nil when it has no label, which launchd would refuse too.
    static func item(from plist: [String: Any], at url: URL, domain: BackgroundItem.Domain,
                     appLookup: (String) -> URL?) -> BackgroundItem? {
        guard let label = plist["Label"] as? String, !label.isEmpty else { return nil }
        // A service inside an app bundle may name its program relative to the bundle instead.
        let program = plist["Program"] as? String ?? plist["BundleProgram"] as? String
            ?? (plist["ProgramArguments"] as? [String])?.first ?? (plist["BundleProgramArguments"] as? [String])?.first
        var item = BackgroundItem(plist: url, label: label, domain: domain, program: program)
        item.runsAtLoad = plist["RunAtLoad"] as? Bool ?? false
        item.keepsAlive = keepsAlive(plist["KeepAlive"])
        item.interval = (plist["StartInterval"] as? NSNumber).map { TimeInterval(truncating: $0) }
        item.hasCalendar = plist["StartCalendarInterval"] != nil
        item.watchesPaths = !((plist["WatchPaths"] as? [String]) ?? []).isEmpty
        item.watchesFolders = !((plist["QueueDirectories"] as? [String]) ?? []).isEmpty
        item.isDisabled = plist["Disabled"] as? Bool ?? false
        if let app = program.flatMap(outermostApp) {
            item.appURL = app
            item.appName = appName(of: app)
        } else if let bundleID = (plist["AssociatedBundleIdentifiers"] as? [String])?.first ?? plist["AssociatedBundleIdentifiers"] as? String,
                  let app = appLookup(bundleID) {
            item.appURL = app
            item.appName = appName(of: app)
        }
        return item
    }

    private static func keepsAlive(_ value: Any?) -> Bool {
        if let flag = value as? Bool { return flag }
        // A dictionary of conditions, such as SuccessfulExit, keeps it alive under those conditions.
        return value is [String: Any]
    }

    /// The app bundle a program sits in: the outermost one, so a helper inside an app counts as the app.
    static func outermostApp(_ program: String) -> URL? {
        let components = program.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard let index = components.firstIndex(where: { $0.hasSuffix(".app") }), index < components.count - 1 else { return nil }
        return URL(fileURLWithPath: "/" + components[...index].joined(separator: "/"), isDirectory: true)
    }

    /// The name on the app's Info.plist, or the bundle's own name.
    static func appName(of app: URL) -> String {
        let info = Files.plist(at: app.appending(path: "Contents/Info.plist"))
        let named = (info?["CFBundleDisplayName"] as? String) ?? (info?["CFBundleName"] as? String)
        return named.flatMap { $0.isEmpty ? nil : $0 } ?? app.deletingPathExtension().lastPathComponent
    }

    // MARK: launchd

    /// Asks launchd what it has loaded: the user's domain and the system's. Neither needs a password.
    static func loaded(uid: uid_t = getuid()) -> Loaded {
        var loaded = Loaded()
        if let output = Shell.run("/bin/launchctl", ["list"], timeout: 15), output.succeeded {
            loaded.user = parseServices(output.stdout)
            loaded.asked = true
        }
        if let output = Shell.run("/bin/launchctl", ["print", "system"], timeout: 15), output.succeeded {
            loaded.system = parseServices(output.stdout)
        }
        return loaded
    }

    /// Reads the `pid status label` lines `launchctl list` and `launchctl print` write, in any amount
    /// of surrounding text. A service that is loaded but not running has a dash in the first column
    /// in one table and a 0 in the other.
    static func parseServices(_ output: String) -> [String: Int?] {
        var services: [String: Int?] = [:]
        for line in output.split(separator: "\n") {
            let fields = line.split(whereSeparator: { $0 == "\t" || $0 == " " }).map(String.init)
            guard fields.count == 3, fields[0] == "-" || Int(fields[0]) != nil, fields[1] == "-" || Int(fields[1]) != nil,
                  fields[2].contains(".") else { continue }
            let pid = Int(fields[0]).flatMap { $0 > 0 ? $0 : nil }
            services[fields[2]] = .some(pid)
        }
        return services
    }
}
