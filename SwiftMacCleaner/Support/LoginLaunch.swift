//
//  LoginLaunch.swift
//  SwiftMacCleaner
//

import AppKit
import Foundation

/// Tells a launch macOS made at login from one the user made, so the first can go without a window.
///
/// macOS says which it was on the event that opens the app, and that event arrives when the launch
/// finishes, after the window is already on screen. To keep the window off the screen altogether the
/// app has to hide before that, on a guess: it is set to open at login, and the user logged in
/// moments ago. The event then settles it, and a wrong guess is undone.
nonisolated enum LoginLaunch {
    /// How long after logging in a launch is taken to be the login's own.
    static let window: TimeInterval = 120

    /// What a debug build can be told to pretend, to see each way a launch can go without logging out:
    /// `--login-launch` is a launch at login guessed right, `--login-guess` a guess that was wrong, and
    /// `--login-late` a launch at login that was not guessed.
    static var pretendsGuess: Bool { pretends("--login-launch") || pretends("--login-guess") }
    static var pretendsLogin: Bool { pretends("--login-launch") || pretends("--login-late") }

    private static func pretends(_ flag: String) -> Bool {
        #if DEBUG
        CommandLine.arguments.contains(flag)
        #else
        false
        #endif
    }

    /// Whether macOS opened the app as one of the items it opens at login. There to be read only
    /// while the launch is finishing, in `applicationDidFinishLaunching`.
    static var wasMadeAtLogin: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent, event.eventID == kAEOpenApplication else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    /// Whether a launch now is probably the one macOS makes at login.
    static func isLikely(isRegistered: Bool, sessionStart: Date?, now: Date = Date()) -> Bool {
        guard isRegistered, let sessionStart else { return false }
        let elapsed = now.timeIntervalSince(sessionStart)
        return elapsed >= 0 && elapsed < window
    }

    /// When this user last logged in at the Mac itself, going by the login records `who` reads.
    static func sessionStart(user: String = NSUserName()) -> Date? {
        setutxent()
        defer { endutxent() }
        var latest: Date?
        while let entry = getutxent() {
            guard Int32(entry.pointee.ut_type) == USER_PROCESS else { continue }
            let name = withUnsafeBytes(of: &entry.pointee.ut_user) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
            let line = withUnsafeBytes(of: &entry.pointee.ut_line) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
            guard name == user, line == "console" else { continue }
            let date = Date(timeIntervalSince1970: Double(entry.pointee.ut_tv.tv_sec))
            if latest.map({ date > $0 }) ?? true { latest = date }
        }
        return latest
    }
}
