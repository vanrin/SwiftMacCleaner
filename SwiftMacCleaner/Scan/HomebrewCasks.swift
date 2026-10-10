//
//  HomebrewCasks.swift
//  SwiftMacCleaner
//

import Foundation

/// An app Homebrew installed as a cask, as its Caskroom records it.
nonisolated struct InstalledCask: Sendable, Hashable {
    /// The name Homebrew knows the cask by, such as "google-chrome".
    var token: String
    /// The cask's version when Homebrew installed it. The app may have updated itself since.
    var version: String
    /// Where the app is.
    var app: URL
    /// From Homebrew's own collection of casks, the only ones whose current version can be looked up.
    var isOfficial = true
}

/// What Homebrew's collection says about a cask today.
nonisolated struct CaskRelease: Sendable, Hashable {
    var version: String
    /// Homebrew no longer installs it.
    var isDisabled = false
}

/// Apps installed through Homebrew: which they are, whether Homebrew has something newer, and the one
/// thing this app has Homebrew do for it, which is upgrade a cask the user asked to update.
///
/// Finding out reads Homebrew's folders and asks its public catalogue; `brew` itself is run only to
/// install. An app that updates itself runs ahead of what Homebrew recorded, so the app's own version
/// is what is compared, and an app that is already current is not offered again.
nonisolated enum HomebrewCasks {
    static let prefixes = ["/opt/homebrew", "/usr/local"]
    static let officialTap = "homebrew/cask"
    /// An upgrade downloads the whole app, which on a slow line takes a while.
    static let upgradeTimeout: TimeInterval = 3_600

    /// Homebrew's own program, looked for only where Homebrew installs it.
    static func brew(prefixes: [String] = prefixes) -> String? {
        prefixes.map { $0 + "/bin/brew" }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func caskrooms(prefixes: [String] = prefixes) -> [URL] {
        prefixes.map { URL(fileURLWithPath: $0 + "/Caskroom", isDirectory: true) }
    }

    /// What a cask may be called: lowercase letters, digits, and a few marks between them.
    static func isValid(token: String) -> Bool {
        guard let first = token.unicodeScalars.first, token.count <= 128 else { return false }
        let plain = { (scalar: Unicode.Scalar) in ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) }
        return plain(first) && token.unicodeScalars.allSatisfy { plain($0) || "+-.@_".unicodeScalars.contains($0) }
    }

    // MARK: What is installed

    /// The apps Homebrew installed, read from its Caskroom. Homebrew moves a cask's app into
    /// Applications and leaves a link to it under the cask's name and version; a cask with no such
    /// link installed something other than an app, or its app has been removed since.
    static func installed(in caskrooms: [URL] = caskrooms()) -> [InstalledCask] {
        var casks: [InstalledCask] = []
        for caskroom in caskrooms {
            for folder in Files.subdirectories(of: caskroom) where isValid(token: folder.lastPathComponent) {
                let receipt = Files.json(at: folder.appending(path: ".metadata/INSTALL_RECEIPT.json"))?["source"] as? [String: Any]
                for version in Files.subdirectories(of: folder) where !version.lastPathComponent.hasPrefix(".") {
                    for link in Files.children(of: version) where link.pathExtension == "app" && Files.isSymlink(link) {
                        let app = link.resolvingSymlinksInPath()
                        guard Files.isDirectory(app) else { continue }
                        casks.append(InstalledCask(
                            token: folder.lastPathComponent,
                            version: receipt?["version"] as? String ?? version.lastPathComponent,
                            app: app,
                            // Older installs kept no record of where a cask came from; nearly all came from Homebrew's own.
                            isOfficial: (receipt?["tap"] as? String).map { $0 == officialTap } ?? true
                        ))
                    }
                }
            }
        }
        return casks
    }

    // MARK: What is current

    /// Where Homebrew's catalogue describes one cask.
    static func lookup(for token: String) -> URL? {
        isValid(token: token) ? URL(string: "https://formulae.brew.sh/api/cask/\(token).json") : nil
    }

    static func release(from data: Data) -> CaskRelease? {
        guard let cask = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let version = cask["version"] as? String, !version.isEmpty else { return nil }
        return CaskRelease(version: version, isDisabled: cask["disabled"] as? Bool ?? false)
    }

    /// The part of a cask's version that is the app's own: "4.31.0" in "4.31.0,153195".
    static func appVersion(of caskVersion: String) -> String {
        String(caskVersion.prefix { $0 != "," })
    }

    /// The update Homebrew can install for an app, or nil when there is none worth installing: the
    /// cask is where Homebrew left it, the app has already updated itself that far, or the cask has
    /// no version to compare ("latest") or is no longer installed by Homebrew at all.
    static func update(for app: InstalledApp, cask: InstalledCask, release: CaskRelease) -> AppUpdate? {
        guard !release.isDisabled, release.version != "latest", release.version != cask.version else { return nil }
        let current = appVersion(of: release.version)
        let installed = app.version.isEmpty ? appVersion(of: cask.version) : app.version
        guard AppUpdateChecker.isNewer(current, than: installed) else { return nil }
        return AppUpdate(id: app.id, installedVersion: installed, newVersion: current, released: nil, size: nil, notes: nil,
                         feed: .homebrew, storeURL: nil, cask: cask.token)
    }

    // MARK: Upgrading

    enum UpgradeResult: Sendable, Equatable {
        case done
        /// Did not go through, with the sentence to show.
        case failed(String)
    }

    /// What `brew` is asked to do. Nil for a name no cask has.
    static func upgradeArguments(for token: String) -> [String]? {
        isValid(token: token) ? ["upgrade", "--cask", "--", token] : nil
    }

    /// The app's own environment, with Homebrew told to keep quiet about itself and report nothing home.
    static func environment(from inherited: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        var environment = inherited
        environment["PATH"] = Shell.searchDirectories.joined(separator: ":")
        for name in ["HOMEBREW_NO_ANALYTICS", "HOMEBREW_NO_ENV_HINTS", "HOMEBREW_NO_COLOR", "HOMEBREW_NO_EMOJI"] {
            environment[name] = "1"
        }
        return environment
    }

    /// Has Homebrew download and install the current version of one cask, and waits for it.
    static func upgrade(token: String, brew: String) -> UpgradeResult {
        guard let arguments = upgradeArguments(for: token) else { return .failed("“\(token)” is not a name Homebrew gives a cask.") }
        guard let output = Shell.run(brew, arguments, timeout: upgradeTimeout, environment: environment()) else {
            return .failed("Homebrew could not be started.")
        }
        return output.succeeded ? .done : .failed(failure(from: output, token: token))
    }

    /// What went wrong, in a sentence: Homebrew's own last word on it, or what it was waiting for.
    static func failure(from output: Shell.Output, token: String) -> String {
        if output.cancelled { return "The update was stopped before Homebrew finished." }
        if output.timedOut { return "Homebrew did not finish within an hour, so it was stopped." }
        let lines = (output.stderr + "\n" + output.stdout).split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        // Some casks install with the system's installer, which wants a password this app never asks for.
        if lines.contains(where: { $0.contains("sudo") && ($0.contains("password") || $0.contains("terminal")) }) {
            return "Homebrew needs your password for this one. Run “brew upgrade --cask \(token)” in Terminal."
        }
        let said = lines.last { $0.hasPrefix("Error:") } ?? lines.last ?? "it gave no reason"
        return "Homebrew did not install it: \(said.replacing("Error: ", with: "").prefix(240))"
    }
}
