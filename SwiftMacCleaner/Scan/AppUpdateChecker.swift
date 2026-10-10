//
//  AppUpdateChecker.swift
//  SwiftMacCleaner
//

import Foundation

/// Asks each app's update feed which version is current, and Homebrew's catalogue for the apps
/// Homebrew installed. It only reads: installing is left to the App Store, to the app's own updater,
/// or to Homebrew when the user asks for it, each of which checks what it downloads.
nonisolated enum AppUpdateChecker {
    /// The storefront tried when the user's own does not carry an app.
    static let fallbackRegion = "us"

    /// The apps that have something newer, in the order the apps were given.
    @concurrent
    static func updates(for apps: [InstalledApp], region: String, session: URLSession = .shared) async -> [AppUpdate] {
        let system = ProcessInfo.processInfo.operatingSystemVersion
        let systemVersion = "\(system.majorVersion).\(system.minorVersion).\(system.patchVersion)"
        var found: [String: AppUpdate] = [:]
        var fromHomebrew: [String: AppUpdate] = [:]

        let storeApps = apps.filter { $0.feed == .appStore }
        var missing = storeApps
        for storefront in [region.lowercased(), fallbackRegion] where !missing.isEmpty {
            guard let data = await fetch(appStoreLookup(for: missing, region: storefront), session: session) else { continue }
            let entries = appStoreEntries(from: data)
            for app in missing {
                guard let entry = entries[app.bundleID.lowercased()] else { continue }
                if let update = entry.update(for: app, systemVersion: systemVersion) { found[app.id] = update }
            }
            missing.removeAll { entries[$0.bundleID.lowercased()] != nil }
        }

        await withTaskGroup(of: AppUpdate?.self) { group in
            for app in apps {
                switch app.feed {
                case .sparkle(let url):
                    group.addTask {
                        guard let data = await fetch(url, session: session) else { return nil }
                        return sparkleUpdate(for: app, appcast: data, systemVersion: systemVersion)
                    }
                case .electron(let url):
                    group.addTask {
                        guard let data = await fetch(url, session: session), let text = String(data: data, encoding: .utf8) else { return nil }
                        return electronUpdate(for: app, manifest: text)
                    }
                case .appStore, .homebrew, nil:
                    break
                }
                // Asked as well as the app's own feed: an update Homebrew has is one this app can install.
                if let cask = app.cask, cask.isOfficial, let lookup = HomebrewCasks.lookup(for: cask.token) {
                    group.addTask {
                        guard let data = await fetch(lookup, session: session), let release = HomebrewCasks.release(from: data) else { return nil }
                        return HomebrewCasks.update(for: app, cask: cask, release: release)
                    }
                }
            }
            for await update in group {
                guard let update else { continue }
                if update.cask == nil { found[update.id] = update } else { fromHomebrew[update.id] = update }
            }
        }
        return merged(feeds: found, homebrew: fromHomebrew, order: apps.map(\.id))
    }

    /// One update for each app, in the order given. Where Homebrew has one too, that is the one
    /// offered, since it can be installed from here, with whatever the app's own feed said about the
    /// release kept beside it.
    static func merged(feeds: [String: AppUpdate], homebrew: [String: AppUpdate], order: [String]) -> [AppUpdate] {
        order.compactMap { id in
            guard var update = homebrew[id] else { return feeds[id] }
            if let feed = feeds[id] {
                update.feed = feed.feed
                update.released = feed.released
                update.size = feed.size
                update.notes = feed.notes
            }
            return update
        }
    }

    private static func fetch(_ url: URL?, session: URLSession) async -> Data? {
        guard let url else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 12)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }

    // MARK: Versions

    /// Whether `candidate` is a later version than `installed`, read the way people read them:
    /// "12.10" is later than "12.9", and "2.0" is later than "2.0b3".
    static func isNewer(_ candidate: String, than installed: String) -> Bool {
        let new = parts(of: candidate)
        let old = parts(of: installed)
        for index in 0..<max(new.count, old.count) {
            switch (index < new.count ? new[index] : nil, index < old.count ? old[index] : nil) {
            case (.number(let a)?, .number(let b)?):
                if a != b { return a > b }
            case (.word(let a)?, .word(let b)?):
                if a != b { return a > b }
            // A number counts as later than a word in the same place: "1.1" against "1.beta".
            case (.number?, .word?): return true
            case (.word?, .number?): return false
            // What is left over decides: more numbers make it later, a trailing word such as "beta" earlier.
            case (.number(let a)?, nil):
                if a != 0 { return true }
            case (nil, .number(let b)?):
                if b != 0 { return false }
            case (.word?, nil): return false
            case (nil, .word?): return true
            case (nil, nil): return false
            }
        }
        return false
    }

    private enum Part {
        case number(UInt64)
        case word(String)
    }

    /// Splits "v2.0b3 (417)" into 2, 0, "b", 3, 417.
    private static func parts(of version: String) -> [Part] {
        var parts: [Part] = []
        var run = ""
        var runIsNumber = false
        func flush() {
            guard !run.isEmpty else { return }
            if runIsNumber {
                parts.append(.number(UInt64(run) ?? .max))
            } else if !(parts.isEmpty && run == "v") {
                parts.append(.word(run))
            }
            run = ""
        }
        for character in version.lowercased() {
            let isNumber = character.isASCII && character.isNumber
            guard isNumber || character.isLetter else {
                flush()
                continue
            }
            if !run.isEmpty, isNumber != runIsNumber { flush() }
            runIsNumber = isNumber
            run.append(character)
        }
        flush()
        return parts
    }

    // MARK: App Store

    static func appStoreLookup(for apps: [InstalledApp], region: String) -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = [
            URLQueryItem(name: "bundleId", value: apps.map(\.bundleID).joined(separator: ",")),
            URLQueryItem(name: "country", value: region),
            URLQueryItem(name: "entity", value: "macSoftware"),
        ]
        return components?.url
    }

    struct AppStoreEntry: Sendable {
        var version: String
        var released: Date?
        var size: Int64?
        var notes: String?
        var minimumSystem: String?
        var page: URL?

        /// The update this entry amounts to for the app, or nil when the app is current or this Mac is too old for it.
        func update(for app: InstalledApp, systemVersion: String) -> AppUpdate? {
            guard AppUpdateChecker.isNewer(version, than: app.version) else { return nil }
            if let minimumSystem, AppUpdateChecker.isNewer(minimumSystem, than: systemVersion) { return nil }
            return AppUpdate(id: app.id, installedVersion: app.version, newVersion: version, released: released,
                             size: size, notes: notes, feed: .appStore, storeURL: page)
        }
    }

    /// What the App Store's lookup returned, keyed by lowercased bundle identifier.
    static func appStoreEntries(from data: Data) -> [String: AppStoreEntry] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = root["results"] as? [[String: Any]] else { return [:] }
        var entries: [String: AppStoreEntry] = [:]
        for result in results {
            guard let bundleID = result["bundleId"] as? String, let version = result["version"] as? String else { continue }
            // The page opens in the App Store app, where the Update button is.
            let page = (result["trackViewUrl"] as? String).flatMap(URLComponents.init(string:)).flatMap { components -> URL? in
                var components = components
                components.scheme = "macappstore"
                return components.url
            }
            entries[bundleID.lowercased()] = AppStoreEntry(
                version: version,
                released: (result["currentVersionReleaseDate"] as? String).flatMap { try? Date($0, strategy: .iso8601) },
                size: (result["fileSizeBytes"] as? String).flatMap(Int64.init),
                notes: (result["releaseNotes"] as? String).flatMap(tidy),
                minimumSystem: result["minimumOsVersion"] as? String,
                page: page
            )
        }
        return entries
    }

    // MARK: Sparkle

    /// One release in an appcast.
    struct AppcastItem: Sendable {
        var build = ""
        var version = ""
        var released: Date?
        var size: Int64?
        var notes: String?
        var minimumSystem: String?
        var maximumSystem: String?
        /// A channel other than the default one, such as "beta".
        var channel: String?
        /// The system the download is for. Nil means the Mac.
        var system: String?
    }

    static func sparkleUpdate(for app: InstalledApp, appcast: Data, systemVersion: String) -> AppUpdate? {
        let eligible = AppcastParser.items(in: appcast).filter { item in
            guard !item.build.isEmpty, item.channel == nil, item.system == nil || item.system == "macos" else { return false }
            if let minimum = item.minimumSystem, isNewer(minimum, than: systemVersion) { return false }
            if let maximum = item.maximumSystem, isNewer(systemVersion, than: maximum) { return false }
            return true
        }
        guard let latest = eligible.max(by: { isNewer($1.build, than: $0.build) }) else { return nil }
        // A feed compares build numbers; an app without one is compared by the version people see.
        let isLater = app.build.isEmpty ? isNewer(latest.version, than: app.version) : isNewer(latest.build, than: app.build)
        guard isLater else { return nil }
        return AppUpdate(id: app.id, installedVersion: app.version.isEmpty ? app.build : app.version,
                         newVersion: latest.version.isEmpty ? latest.build : latest.version,
                         released: latest.released, size: latest.size, notes: latest.notes,
                         feed: app.feed ?? .appStore, storeURL: nil)
    }

    // MARK: Electron

    /// Reads the `version` and `releaseDate` lines at the top level of a `latest-mac.yml`.
    static func electronUpdate(for app: InstalledApp, manifest: String) -> AppUpdate? {
        var values: [String: String] = [:]
        for line in manifest.split(whereSeparator: \.isNewline) where line.first?.isWhitespace == false {
            guard let colon = line.firstIndex(of: ":") else { continue }
            values[String(line[..<colon])] = line[line.index(after: colon)...]
                .trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
        }
        guard let version = values["version"], !version.isEmpty, isNewer(version, than: app.version) else { return nil }
        let released = values["releaseDate"].flatMap { text in
            try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
        } ?? values["releaseDate"].flatMap { try? Date($0, strategy: .iso8601) }
        return AppUpdate(id: app.id, installedVersion: app.version, newVersion: version, released: released,
                         size: nil, notes: nil, feed: app.feed ?? .appStore, storeURL: nil)
    }

    // MARK: Text

    /// Release notes as plain text: tags dropped, the common entities decoded, blank lines collapsed.
    static func tidy(_ text: String) -> String? {
        var plain = text.replacing(#/<style[^>]*>.*?</style>/#.ignoresCase().dotMatchesNewlines(), with: "")
        plain = plain.replacing(#/<(br|/p|/li|/h[1-6]|/div)\s*/?>/#.ignoresCase(), with: "\n")
        plain = plain.replacing(#/<li[^>]*>/#.ignoresCase(), with: "• ")
        plain = plain.replacing(#/<[^>]+>/#, with: "")
        for (entity, character) in [("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'")] {
            plain = plain.replacing(entity, with: character)
        }
        let lines = plain.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}

/// Reads the releases out of a Sparkle appcast, which is an RSS feed with Sparkle's own fields.
nonisolated final class AppcastParser: NSObject, XMLParserDelegate {
    private var items: [AppUpdateChecker.AppcastItem] = []
    private var current: AppUpdateChecker.AppcastItem?
    private var text = ""

    private static let dateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter
    }()

    static func items(in data: Data) -> [AppUpdateChecker.AppcastItem] {
        let delegate = AppcastParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        text = ""
        if elementName == "item" {
            current = AppUpdateChecker.AppcastItem()
        } else if elementName == "enclosure", current != nil {
            if let build = attributes["sparkle:version"] { current?.build = build }
            if let version = attributes["sparkle:shortVersionString"] { current?.version = version }
            if let length = attributes["length"].flatMap(Int64.init), length > 0 { current?.size = length }
            if let system = attributes["sparkle:os"] { current?.system = system.lowercased() }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(data: CDATABlock, encoding: .utf8) ?? ""
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = ""
        guard current != nil else { return }
        switch elementName {
        case "item":
            if let current { items.append(current) }
            current = nil
        case "sparkle:version": current?.build = value
        case "sparkle:shortVersionString": current?.version = value
        case "sparkle:minimumSystemVersion": current?.minimumSystem = value
        case "sparkle:maximumSystemVersion": current?.maximumSystem = value
        case "sparkle:channel": current?.channel = value.isEmpty ? nil : value
        case "pubDate": current?.released = Self.dateFormat.date(from: value)
        case "description": current?.notes = AppUpdateChecker.tidy(value)
        default: break
        }
    }
}
