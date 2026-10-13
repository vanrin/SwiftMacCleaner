//
//  OpenApps.swift
//  SwiftMacCleaner
//

import AppKit
import Observation

/// An app that is open, by the two names something of its may be filed under.
nonisolated struct OpenApp: Hashable, Identifiable, Sendable {
    var bundleID: String
    var name: String

    var id: String { bundleID }

    /// Whether something filed under `key` is this app's to keep. A cache folder is named after the
    /// app's bundle identifier, after something that starts with it, after the app itself, or after
    /// its maker, in which case every app of that maker's has a share in it.
    func keeps(_ key: String) -> Bool {
        let key = key.lowercased()
        let identifier = bundleID.lowercased()
        guard !key.isEmpty else { return false }
        if key == identifier || key.hasPrefix(identifier + ".") { return true }
        // "com.google" holds what com.google.Chrome keeps; "com" alone says nothing.
        if key.contains("."), identifier.hasPrefix(key + ".") { return true }
        guard !key.contains(".") else { return false }
        let plain = { (text: String) in text.lowercased().filter { $0.isLetter || $0.isNumber } }
        if plain(key) == plain(name) { return true }
        let parts = identifier.split(separator: ".")
        return parts.count >= 3 && parts[1] == key
    }
}

/// An open app that something in a plan waits for, and how much of the plan that is.
nonisolated struct BlockingApp: Identifiable, Hashable, Sendable {
    var app: OpenApp
    var size: Int64

    var id: String { app.id }
}

nonisolated extension RunningApps {
    /// The apps the user has open and could quit: the ones with a place in the Dock, this app left out.
    static func open() -> [OpenApp] {
        let own = Bundle.main.bundleIdentifier
        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.activationPolicy == .regular, let identifier = app.bundleIdentifier, identifier != own else { return nil }
            return OpenApp(bundleID: identifier, name: app.localizedName ?? identifier)
        }
    }
}

nonisolated extension Sequence<FindingItem> {
    /// The items that wait because an app that keeps them is open, each with the apps it waits for.
    func waiting(for apps: [OpenApp]) -> [String: [OpenApp]] {
        var waiting: [String: [OpenApp]] = [:]
        for item in self {
            guard let key = item.keptBy else { continue }
            let keepers = apps.filter { $0.keeps(key) }
            if !keepers.isEmpty { waiting[item.id] = keepers }
        }
        return waiting
    }
}

/// Which apps are open right now, for everything that waits on one. A cache is only cleaned once
/// the app that keeps it has quit, and the confirmation offers to ask each of them to.
///
/// There is one for the whole app. It hears from the workspace when an app opens or quits, so a
/// screen that reads it follows along.
@Observable
final class OpenApps {
    private(set) var apps: [OpenApp] = []
    /// A list that stands in for the apps really open, for the demo screens and for tests. While one
    /// is set macOS is not asked anything, and quitting an app only takes it off the list.
    @ObservationIgnored var list: (() -> [OpenApp])? {
        didSet { refresh() }
    }

    init() {
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
    }

    func refresh() {
        let current = list?() ?? RunningApps.open()
        if current != apps { apps = current }
    }

    /// Whether an app with this identifier is open. An app with no place in the Dock is not in the
    /// list, so macOS is asked about it directly as well.
    func isOpen(bundleID: String) -> Bool {
        apps.contains { $0.bundleID == bundleID } || (list == nil && RunningApps.isRunning(bundleID: bundleID))
    }

    /// Asks the app to quit, the way its own Quit command would, so it can still ask about unsaved
    /// work. It is never forced. The list follows once the app is gone.
    func quit(_ app: OpenApp) {
        if let list {
            let remaining = list().filter { $0 != app }
            self.list = { remaining }
            return
        }
        for instance in NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID) {
            instance.terminate()
        }
        Task {
            // Quitting takes a moment, and longer when the app stops to ask something.
            for _ in 0..<40 where apps.contains(app) {
                try? await Task.sleep(for: .milliseconds(250))
                refresh()
            }
        }
    }
}
