//
//  LoginItemScanner.swift
//  SwiftMacCleaner
//

import Foundation

/// An app that opens by itself when the user logs in: what System Settings lists under Open at Login.
nonisolated struct LoginItem: Identifiable, Sendable, Hashable {
    var name: String
    var path: URL
    /// Opens without showing its windows.
    var isHidden = false
    /// The app is still where the item points. A stale item opens nothing and only slows login down.
    var exists = true

    var id: String { path.path }
}

nonisolated struct LoginItemScan: Sendable {
    var items: [LoginItem] = []
    /// Why the list could not be read, when it could not.
    var failure: String? = nil
}

/// Reads and removes login items through System Events, the one door macOS leaves open to another
/// app's items. The first time, macOS asks whether SwiftMacCleaner may control System Events.
nonisolated enum LoginItemScanner {
    static let listScript = "JSON.stringify(Application('System Events').loginItems().map(i => ({name: i.name(), path: i.path(), hidden: i.hidden()})))"

    static func scan() -> LoginItemScan {
        guard let output = Shell.run("/usr/bin/osascript", ["-l", "JavaScript", "-e", listScript], timeout: 30) else {
            return LoginItemScan(failure: "osascript could not be started.")
        }
        guard output.succeeded else { return LoginItemScan(failure: failureReason(output.stderr)) }
        guard let items = items(fromJSON: Data(output.stdout.utf8)) else {
            return LoginItemScan(failure: "System Events answered with something that could not be read.")
        }
        return LoginItemScan(items: items)
    }

    static func failureReason(_ stderr: String) -> String {
        if stderr.contains("-1743") || stderr.localizedCaseInsensitiveContains("not authorized") || stderr.localizedCaseInsensitiveContains("not allowed") {
            return "macOS did not let SwiftMacCleaner ask System Events. Allow it under Privacy & Security › Automation, then scan again."
        }
        let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "System Events did not answer." : trimmed
    }

    /// The items as System Events describes them, in the order the user sees them.
    static func items(fromJSON data: Data) -> [LoginItem]? {
        guard let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        return entries.compactMap { entry in
            guard let path = entry["path"] as? String, !path.isEmpty else { return nil }
            let url = URL(fileURLWithPath: path)
            let name = (entry["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? url.deletingPathExtension().lastPathComponent
            return LoginItem(name: name, path: url, isHidden: entry["hidden"] as? Bool ?? false, exists: Files.exists(url))
        }
    }

    /// The command that takes one item off the list. The app itself stays where it is.
    static func removeCommand(for item: LoginItem) -> [String] {
        ["/usr/bin/osascript", "-e",
         "tell application \"System Events\" to delete (every login item whose path is \"\(appleScriptEscaped(item.path.path))\")"]
    }

    static func appleScriptEscaped(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}
