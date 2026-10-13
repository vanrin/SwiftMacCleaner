//
//  RunningApp.swift
//  SwiftMacCleaner
//

import AppKit

/// An app that is running and could be asked to quit: one with a place in the Dock, or one that
/// lives in the menu bar.
nonisolated struct RunningApp: Equatable, Sendable {
    /// Where the app's bundle is.
    var path: String
    var bundleID: String
    var name: String
    /// Has a place in the Dock.
    var isRegular: Bool

    /// The apps running right now. Helpers that run unseen are left out: they belong to the app that started them.
    static func all() -> [RunningApp] {
        NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.activationPolicy != .prohibited, let url = app.bundleURL, let identifier = app.bundleIdentifier else { return nil }
            return RunningApp(path: url.standardizedFileURL.path, bundleID: identifier,
                              name: app.localizedName ?? url.deletingPathExtension().lastPathComponent,
                              isRegular: app.activationPolicy == .regular)
        }
    }
}
