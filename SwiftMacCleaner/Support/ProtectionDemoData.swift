//
//  ProtectionDemoData.swift
//  SwiftMacCleaner
//

import Foundation

/// A made-up Mac for the Protection screens: what its tools would have printed.
nonisolated enum ProtectionDemoData {
    private static func said(_ text: String, status: Int32 = 0) -> Shell.Output {
        Shell.Output(status: status, stdout: text, stderr: "", timedOut: false)
    }

    /// A Mac with its firewall off, Remote Login on and malware definitions that stopped arriving,
    /// or one with everything in place.
    static func facts(allInPlace: Bool = false, now: Date = Date()) -> ProtectionScanner.Facts {
        ProtectionScanner.Facts(
            gatekeeper: said("assessments enabled"),
            fileVault: said("FileVault is On."),
            firewall: said(allInPlace ? "Firewall is enabled. (State = 1)" : "Firewall is disabled. (State = 0)"),
            integrity: said("System Integrity Protection status: enabled."),
            screenLock: said("screenLock delay is immediate"),
            listening: said("""
            tcp4       0      0  127.0.0.1.11434        *.*                    LISTEN
            tcp46      0      0  *.\(allInPlace ? 7000 : 22)                   *.*                    LISTEN
            """),
            updateSettings: [ProtectionScanner.installsSystemUpdates: true],
            lastUpdateCheck: now.addingTimeInterval(-2 * 86_400),
            definitions: ProtectionScanner.Definitions(version: "5366", updated: now.addingTimeInterval(-(allInPlace ? 4 : 96) * 86_400))
        )
    }
}
