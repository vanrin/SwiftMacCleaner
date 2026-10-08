//
//  Uninstaller.swift
//  SwiftMacCleaner
//

import Foundation

/// Turns ticked app files into a plan the cleaner can carry out. Everything goes to the Trash,
/// the app itself first, so an app that could not be moved keeps the files it needs to run.
nonisolated enum Uninstaller {
    static func stepID(for app: InstalledApp) -> String { "uninstall/\(app.id)" }

    /// One step per app that has anything ticked, in the order the apps are given.
    static func plan(for apps: [InstalledApp], selection: Set<String>) -> CleanPlan {
        var plan = CleanPlan()
        for app in apps {
            // The bundle is listed first, so it is moved first.
            let files = app.files.filter { selection.contains($0.id) }
            guard !files.isEmpty else { continue }
            let removesApp = files.contains { $0.kind == .binaries }
            plan.steps.append(CleanStep(
                id: stepID(for: app),
                title: removesApp ? app.name : "\(app.name): its files only",
                tier: .review,
                method: .trash,
                summary: summary(removesApp: removesApp, related: files.count - (removesApp ? 1 : 0)),
                size: files.reduce(0) { $0 + $1.size },
                operations: files.map { CleanOperation(itemID: $0.id, kind: .trash($0.url), size: $0.size) },
                waitsFor: .app(bundleID: app.bundleID, name: app.name),
                requiresFirst: removesApp
            ))
        }
        return plan
    }

    private static func summary(removesApp: Bool, related: Int) -> String {
        let items = related == 1 ? "1 related item" : "\(related) related items"
        if !removesApp { return "Move \(items) to the Trash. The app stays and starts fresh" }
        return related == 0 ? "Move the app to the Trash" : "Move the app and \(items) to the Trash"
    }

    /// The apps whose bundle is ticked, which is what the guard lets through outside the home folder.
    static func bundles(in apps: [InstalledApp], selection: Set<String>) -> [URL] {
        apps.compactMap(\.bundleFile).filter { selection.contains($0.id) }.map(\.url)
    }

    /// Whether the plan moves an app only Finder can move, in which case macOS asks for a password.
    static func needsPassword(_ apps: [InstalledApp], selection: Set<String>) -> Bool {
        apps.contains { app in app.needsPassword && app.bundleFile.map { selection.contains($0.id) } == true }
    }
}
