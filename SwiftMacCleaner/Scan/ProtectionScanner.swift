//
//  ProtectionScanner.swift
//  SwiftMacCleaner
//

import Foundation

/// One of this Mac's own defences, as macOS lets any user read it. None of them is changed from here:
/// each is the user's to switch on in System Settings, and one only from Recovery.
nonisolated enum ProtectionCheck: String, CaseIterable, Identifiable, Sendable {
    case fileVault, screenLock, gatekeeper, systemIntegrity, malwareDefinitions, updates, firewall, sharing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fileVault: "FileVault"
        case .screenLock: "Screen Lock"
        case .gatekeeper: "Gatekeeper"
        case .systemIntegrity: "System Integrity Protection"
        case .malwareDefinitions: "Malware Definitions"
        case .updates: "Automatic Updates"
        case .firewall: "Firewall"
        case .sharing: "Remote Access"
        }
    }

    /// What it is there for, in a sentence.
    var purpose: String {
        switch self {
        case .fileVault: "Encrypts the startup disk, so a lost or stolen Mac gives up nothing without your password."
        case .screenLock: "Asks for your password when the Mac wakes or starts, so nobody can sit down at it while you are away."
        case .gatekeeper: "Checks an app you downloaded before it first opens: who made it, and that Apple found no known malware in it."
        case .systemIntegrity: "Keeps the system's own files and processes out of reach, even of a program that has your password."
        case .malwareDefinitions: "The list of known malware that macOS checks apps against, called XProtect. Apple updates it every few weeks."
        case .updates: "Keeps macOS looking for updates, and installing the security ones without being asked."
        case .firewall: "Turns away incoming connections to apps you have not allowed, which matters most on networks you do not run."
        case .sharing: "Remote Login, Screen Sharing, File Sharing and Remote Apple Events let other computers into this Mac."
        }
    }

    /// The symbol on its lens. These are macOS's features, not the app's, so they are system symbols.
    var symbol: String {
        switch self {
        case .fileVault: "lock.fill"
        case .screenLock: "lock.display"
        case .gatekeeper: "checkmark.seal.fill"
        case .systemIntegrity: "lock.shield.fill"
        case .malwareDefinitions: "ladybug.fill"
        case .updates: "arrow.triangle.2.circlepath"
        case .firewall: "flame.fill"
        case .sharing: "network"
        }
    }

    /// Where in System Settings it is changed. Nil for the one that is changed only from Recovery.
    var settings: URL? {
        let pane: String? = switch self {
        case .fileVault: "com.apple.settings.PrivacySecurity.extension?FileVault"
        case .screenLock: "com.apple.Lock-Screen-Settings.extension"
        case .gatekeeper: "com.apple.settings.PrivacySecurity.extension?Security"
        case .systemIntegrity: nil
        case .malwareDefinitions, .updates: "com.apple.Software-Update-Settings.extension"
        case .firewall: "com.apple.Network-Settings.extension?Firewall"
        case .sharing: "com.apple.Sharing-Settings.extension"
        }
        return pane.flatMap { URL(string: "x-apple.systempreferences:" + $0) }
    }
}

/// What one check found on this Mac.
nonisolated struct ProtectionFinding: Identifiable, Sendable, Equatable {
    enum State: Sendable, Equatable {
        /// As Apple ships it, or stricter.
        case inPlace
        /// Off, or weaker than it could be.
        case needsLook
        /// macOS would not say.
        case unknown
    }

    var check: ProtectionCheck
    var state: State
    /// The setting as it stands, in a few words: "On", "Off", "Version 5366, updated 4 days ago".
    var status: String
    /// What it means and what can be done, when it needs a look or could not be read.
    var advice: String? = nil
    /// Where it is changed, when that is not the check's usual pane.
    var pane: URL? = nil

    var id: ProtectionCheck { check }
    var settings: URL? { pane ?? check.settings }
}

/// Reads how this Mac is protected. It asks the tools macOS has for the purpose, and reads two
/// preference files and two bundles; none of it needs a password, and nothing is changed.
nonisolated enum ProtectionScanner {
    static let commandTimeout: TimeInterval = 5
    /// A password asked for later than this after the screen goes dark is said to be late.
    static let longestLockDelay = 900.0
    /// Apple updates the definitions every few weeks, so this long without one means they are not arriving.
    static let staleDefinitionDays = 60.0
    /// Where macOS keeps the list of known malware: where updates are put, and the copy that came with the system.
    static let definitionBundles = ["/var/protected/xprotect/XProtect.bundle", "/Library/Apple/System/Library/CoreServices/XProtect.bundle"]
    /// The services that let another computer in, by the port each listens on.
    static let remoteServices: [(port: Int, name: String)] = [
        (22, "Remote Login"), (5900, "Screen Sharing"), (445, "File Sharing"), (548, "File Sharing"), (3031, "Remote Apple Events"),
    ]
    static let usersPane = URL(string: "x-apple.systempreferences:com.apple.Users-Groups-Settings.extension")

    /// The list of known malware as it is installed.
    struct Definitions: Sendable, Hashable {
        var version: String
        var updated: Date?
    }

    /// What the checks are decided on. Tests make one up.
    struct Facts: Sendable {
        /// What `spctl --status` said. Nil, here and below, when the tool could not be run.
        var gatekeeper: Shell.Output? = nil
        /// `fdesetup status`.
        var fileVault: Shell.Output? = nil
        /// `socketfilterfw --getglobalstate`.
        var firewall: Shell.Output? = nil
        /// `csrutil status`.
        var integrity: Shell.Output? = nil
        /// `sysadminctl -screenLock status`.
        var screenLock: Shell.Output? = nil
        /// `netstat -anp tcp`: what this Mac accepts connections on.
        var listening: Shell.Output? = nil
        /// The account macOS logs into by itself at startup, when there is one.
        var automaticLogin: String? = nil
        /// The switches under Automatic Updates that have been set either way. One that is missing is as Apple ships it.
        var updateSettings: [String: Bool] = [:]
        /// When macOS last managed to ask Apple for updates.
        var lastUpdateCheck: Date? = nil
        var definitions: Definitions? = nil
    }

    // MARK: Reading

    @concurrent
    static func gather() async -> Facts {
        async let gatekeeper = run("/usr/sbin/spctl", ["--status"])
        async let fileVault = run("/usr/bin/fdesetup", ["status"])
        async let firewall = run("/usr/libexec/ApplicationFirewall/socketfilterfw", ["--getglobalstate"])
        async let integrity = run("/usr/bin/csrutil", ["status"])
        async let screenLock = run("/usr/sbin/sysadminctl", ["-screenLock", "status"])
        async let listening = run("/usr/sbin/netstat", ["-anp", "tcp"])
        var facts = await Facts(gatekeeper: gatekeeper, fileVault: fileVault, firewall: firewall, integrity: integrity,
                                screenLock: screenLock, listening: listening)
        facts.automaticLogin = preference("autoLoginUser", in: "com.apple.loginwindow") as? String
        for key in updateSwitches {
            if let value = preference(key, in: updateDomain) as? Bool { facts.updateSettings[key] = value }
        }
        facts.lastUpdateCheck = preference("LastSuccessfulDate", in: updateDomain) as? Date
        facts.definitions = definitions()
        return facts
    }

    @concurrent
    private static func run(_ tool: String, _ arguments: [String]) async -> Shell.Output? {
        Shell.run(tool, arguments, timeout: commandTimeout)
    }

    static let updateDomain = "com.apple.SoftwareUpdate"
    static let checksForUpdates = "AutomaticCheckEnabled"
    static let installsSecurityData = "ConfigDataInstall"
    static let installsCriticalUpdates = "CriticalUpdateInstall"
    static let installsSystemUpdates = "AutomaticallyInstallMacOSUpdates"
    static let updateSwitches = [checksForUpdates, installsSecurityData, installsCriticalUpdates, installsSystemUpdates]

    /// A preference as it takes effect: what a management profile sets wins over what the Mac's own file says.
    private static func preference(_ key: String, in domain: String) -> Any? {
        CFPreferencesCopyAppValue(key as CFString, domain as CFString)
    }

    /// The newer of the installed lists: macOS uses whichever is.
    static func definitions(in bundles: [String] = definitionBundles) -> Definitions? {
        let found = bundles.compactMap { path -> Definitions? in
            let info = URL(fileURLWithPath: path, isDirectory: true).appending(path: "Contents/Info.plist")
            guard let plist = NSDictionary(contentsOf: info),
                  let version = (plist["CFBundleShortVersionString"] ?? plist["CFBundleVersion"]) as? String else { return nil }
            return Definitions(version: version, updated: Files.modificationDate(info))
        }
        return found.max { first, second in
            let order = first.version.compare(second.version, options: .numeric)
            return order == .orderedSame ? (first.updated ?? .distantPast) < (second.updated ?? .distantPast) : order == .orderedAscending
        }
    }

    // MARK: Judging

    /// The findings, in the order the checks are listed.
    static func findings(from facts: Facts, now: Date = Date()) -> [ProtectionFinding] {
        ProtectionCheck.allCases.map { check in
            switch check {
            case .fileVault: fileVault(facts.fileVault)
            case .screenLock: screenLock(facts.screenLock, automaticLogin: facts.automaticLogin)
            case .gatekeeper: gatekeeper(facts.gatekeeper)
            case .systemIntegrity: systemIntegrity(facts.integrity)
            case .malwareDefinitions: malwareDefinitions(facts.definitions, now: now)
            case .updates: updates(facts.updateSettings, lastCheck: facts.lastUpdateCheck, now: now)
            case .firewall: firewall(facts.firewall)
            case .sharing: sharing(facts.listening)
            }
        }
    }

    /// What a tool printed, from both of the places it may print to, in lower case. Nil when it gave no answer.
    private static func words(_ output: Shell.Output?) -> String? {
        guard let output, !output.timedOut, !output.cancelled else { return nil }
        return (output.stdout + "\n" + output.stderr).lowercased()
    }

    private static func unknown(_ check: ProtectionCheck) -> ProtectionFinding {
        ProtectionFinding(check: check, state: .unknown, status: "Could not be read",
                          advice: "macOS gave no answer that could be read. \(check.settings == nil ? "Nothing was changed." : "System Settings shows how it is set.")")
    }

    static func fileVault(_ output: Shell.Output?) -> ProtectionFinding {
        guard let said = words(output) else { return unknown(.fileVault) }
        if said.contains("filevault is on") {
            // Switching it off takes a while, and the disk says it is on until it is done.
            if said.contains("decryption in progress") {
                return ProtectionFinding(check: .fileVault, state: .needsLook, status: "Being switched off",
                                         advice: "The disk is being decrypted. When that is done, what is on it can be read without your password.")
            }
            return ProtectionFinding(check: .fileVault, state: .inPlace, status: "On")
        }
        if said.contains("filevault is off") {
            if said.contains("encryption in progress") {
                return ProtectionFinding(check: .fileVault, state: .inPlace, status: "Being switched on")
            }
            return ProtectionFinding(check: .fileVault, state: .needsLook, status: "Off",
                                     advice: "Anyone who gets hold of this Mac can read its disk. Turn FileVault on in Privacy & Security, and keep the recovery key somewhere safe.")
        }
        return unknown(.fileVault)
    }

    static func screenLock(_ output: Shell.Output?, automaticLogin: String?) -> ProtectionFinding {
        // Logging in by itself undoes the rest: a restart is all it takes to get in.
        if let automaticLogin, !automaticLogin.isEmpty {
            return ProtectionFinding(check: .screenLock, state: .needsLook, status: "Logs in as \(automaticLogin) without a password",
                                     advice: "Whoever starts this Mac is logged in. Switch off “Automatically log in as” in Users & Groups.",
                                     pane: usersPane)
        }
        guard let said = words(output) else { return unknown(.screenLock) }
        if said.contains("screenlock is off") {
            return ProtectionFinding(check: .screenLock, state: .needsLook, status: "No password after sleep",
                                     advice: "Waking this Mac is enough to use it. Set “Require password after screen saver begins or display is turned off” in Lock Screen.")
        }
        if said.contains("delay is immediate") {
            return ProtectionFinding(check: .screenLock, state: .inPlace, status: "Password required at once")
        }
        if let match = said.firstMatch(of: /delay is ([0-9]+(\.[0-9]+)?) seconds/), let seconds = Double(match.1) {
            let wait = Duration.seconds(Int(seconds)).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide, maximumUnitCount: 1))
            guard seconds > longestLockDelay else {
                return ProtectionFinding(check: .screenLock, state: .inPlace, status: seconds < 1 ? "Password required at once" : "Password required after \(wait)")
            }
            return ProtectionFinding(check: .screenLock, state: .needsLook, status: "Password required only after \(wait)",
                                     advice: "For that long after the screen goes dark, waking this Mac is enough to use it. Choose a shorter time in Lock Screen.")
        }
        return unknown(.screenLock)
    }

    static func gatekeeper(_ output: Shell.Output?) -> ProtectionFinding {
        guard let said = words(output) else { return unknown(.gatekeeper) }
        if said.contains("assessments enabled") { return ProtectionFinding(check: .gatekeeper, state: .inPlace, status: "On") }
        if said.contains("assessments disabled") {
            return ProtectionFinding(check: .gatekeeper, state: .needsLook, status: "Off",
                                     advice: "Any downloaded app opens without being checked. Choose “App Store & Known Developers” under Security in Privacy & Security.")
        }
        return unknown(.gatekeeper)
    }

    static func systemIntegrity(_ output: Shell.Output?) -> ProtectionFinding {
        guard let said = words(output) else { return unknown(.systemIntegrity) }
        let recovery = "It is changed only from Recovery: start up there, open Terminal and run “csrutil enable”."
        // Parts of it can be switched off one by one, and then the first line still says "enabled" or "unknown".
        if said.contains("custom configuration") {
            return ProtectionFinding(check: .systemIntegrity, state: .needsLook, status: "Partly switched off",
                                     advice: "Some of its protections are off, usually for a driver or a debugging tool. \(recovery)")
        }
        if said.contains("status: enabled") { return ProtectionFinding(check: .systemIntegrity, state: .inPlace, status: "On") }
        if said.contains("status: disabled") {
            return ProtectionFinding(check: .systemIntegrity, state: .needsLook, status: "Off",
                                     advice: "A program with your password can change the system itself. It is usually off on purpose, for a driver or a debugging tool. \(recovery)")
        }
        return unknown(.systemIntegrity)
    }

    static func malwareDefinitions(_ definitions: Definitions?, now: Date = Date()) -> ProtectionFinding {
        guard let definitions else { return unknown(.malwareDefinitions) }
        guard let updated = definitions.updated else {
            return ProtectionFinding(check: .malwareDefinitions, state: .inPlace, status: "Version \(definitions.version)")
        }
        let status = "Version \(definitions.version), updated \(relative(updated, to: now))"
        guard now.timeIntervalSince(updated) > staleDefinitionDays * 86_400 else {
            return ProtectionFinding(check: .malwareDefinitions, state: .inPlace, status: status)
        }
        return ProtectionFinding(check: .malwareDefinitions, state: .needsLook, status: status,
                                 advice: "Apple has sent newer ones since, and they have not arrived. Check that “Install Security Responses and system files” is on in Software Update, and that this Mac gets online.")
    }

    static func updates(_ settings: [String: Bool], lastCheck: Date?, now: Date = Date()) -> ProtectionFinding {
        if settings[checksForUpdates] == false {
            return ProtectionFinding(check: .updates, state: .needsLook, status: "Not checking for updates",
                                     advice: "macOS learns of a security fix only when you look for one. Turn on “Check for updates” under Automatic Updates in Software Update.")
        }
        if settings[installsSecurityData] == false || settings[installsCriticalUpdates] == false {
            return ProtectionFinding(check: .updates, state: .needsLook, status: "Security updates wait to be installed by hand",
                                     advice: "New malware definitions and urgent fixes are not installed on their own. Turn on “Install Security Responses and system files” under Automatic Updates in Software Update.")
        }
        var status = settings[installsSystemUpdates] == true ? "Installs security and macOS updates on its own" : "Installs security updates on its own"
        if let lastCheck { status += ", last checked \(relative(lastCheck, to: now))" }
        return ProtectionFinding(check: .updates, state: .inPlace, status: status)
    }

    static func firewall(_ output: Shell.Output?) -> ProtectionFinding {
        guard let said = words(output) else { return unknown(.firewall) }
        if said.contains("state = 2") || said.contains("blocking all") {
            return ProtectionFinding(check: .firewall, state: .inPlace, status: "On, blocking all incoming connections")
        }
        if said.contains("state = 1") || said.contains("firewall is enabled") {
            return ProtectionFinding(check: .firewall, state: .inPlace, status: "On")
        }
        if said.contains("state = 0") || said.contains("firewall is disabled") {
            return ProtectionFinding(check: .firewall, state: .needsLook, status: "Off",
                                     advice: "Every app on this Mac that listens for connections can be reached by any computer on the same network. Turn it on under Firewall in Network; macOS then asks the first time an app wants to accept connections.")
        }
        return unknown(.firewall)
    }

    static func sharing(_ output: Shell.Output?) -> ProtectionFinding {
        guard let output, output.succeeded else { return unknown(.sharing) }
        let open = openPorts(in: output.stdout)
        var names: [String] = []
        for service in remoteServices where open.contains(service.port) && !names.contains(service.name) { names.append(service.name) }
        guard !names.isEmpty else { return ProtectionFinding(check: .sharing, state: .inPlace, status: "Off") }
        return ProtectionFinding(check: .sharing, state: .needsLook, status: "\(ListFormat.string(names)) \(names.count == 1 ? "is" : "are") on",
                                 advice: "Anyone on your network who knows a password for this Mac can use \(names.count == 1 ? "it" : "them"). Switch off what you do not use under Sharing in General.")
    }

    /// The ports this Mac accepts connections on from other computers, out of what `netstat -anp tcp`
    /// lists. One that listens only to the Mac itself is left out.
    static func openPorts(in listing: String) -> Set<Int> {
        var ports: Set<Int> = []
        for line in listing.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            // "tcp4  0  0  127.0.0.1.5900  *.*  LISTEN": the address ends in the port, after its last dot.
            guard fields.count >= 6, fields[0].hasPrefix("tcp"), fields[5] == "LISTEN", let dot = fields[3].lastIndex(of: "."),
                  let port = Int(fields[3][fields[3].index(after: dot)...]) else { continue }
            let address = fields[3][..<dot]
            if address == "127.0.0.1" || address == "::1" || address.hasPrefix("fe80::1%lo") { continue }
            ports.insert(port)
        }
        return ports
    }

    /// "4 days ago".
    private static func relative(_ date: Date, to now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: min(date, now), relativeTo: now)
    }
}
