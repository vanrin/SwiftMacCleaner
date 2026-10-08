//
//  FinderTrash.swift
//  Mac Disk Cleaner
//

import Foundation

/// Moves something to the Trash by asking Finder to do it.
///
/// An app installed by the App Store or by a package belongs to root, so this app cannot move it.
/// Finder can: it asks for the password itself, the way it does when the app is dragged to the Trash.
nonisolated enum FinderTrash {
    enum Outcome: Sendable {
        /// Moved. The place in the Trash is nil when Finder did not say where it put it.
        case trashed(URL?)
        case failed(String)
    }

    /// The AppleScript that moves `path` to the Trash and returns where it ended up.
    static func script(for path: String) -> String {
        let quoted = path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return """
        tell application "Finder"
            set moved to delete (POSIX file "\(quoted)" as alias)
            return POSIX path of (moved as alias)
        end tell
        """
    }

    static func move(_ url: URL, timeout: TimeInterval = 300) -> Outcome {
        guard let output = Shell.run("/usr/bin/osascript", ["-e", script(for: url.path)], timeout: timeout) else {
            return .failed("Could not ask Finder to move \(url.path)")
        }
        if output.timedOut { return .failed("Finder did not answer about \(url.path)") }
        guard output.status == 0 else { return .failed(reason(for: url, error: output.stderr)) }
        let path = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return .trashed(path.isEmpty ? nil : URL(fileURLWithPath: path))
    }

    /// What went wrong, in words. AppleScript reports -128 for a cancelled prompt and -1743 when
    /// macOS has not let this app send requests to Finder.
    static func reason(for url: URL, error: String) -> String {
        let name = url.lastPathComponent
        if error.contains("-128") { return "\(name) was left alone: the password prompt was cancelled" }
        if error.contains("-1743") {
            return "macOS did not let this app ask Finder to move \(name). Allow it under Privacy & Security, Automation, or drag \(name) to the Trash yourself"
        }
        let detail = error.trimmingCharacters(in: .whitespacesAndNewlines)
        return "Finder could not move \(url.path) to the Trash" + (detail.isEmpty ? "" : ": \(detail)")
    }
}
