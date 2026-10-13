//
//  ProtectionModel.swift
//  SwiftMacCleaner
//

import AppKit
import Observation
import SwiftUI

/// State behind the Protection screen: how this Mac's own defences are set, and which of the ones
/// that are off the user has said to leave that way. It only reads; what it finds is changed in
/// System Settings, by the user.
@Observable
final class ProtectionModel {
    enum Phase {
        case idle, scanning, results
    }

    let settings: AppSettings
    /// Called when a scan ends or is stopped, so the overview knows when every part of its scan is done.
    @ObservationIgnored var didScan: () -> Void = {}
    /// Asks macOS how it is set. Tests and the made-up screens answer for it.
    @ObservationIgnored var gather: @Sendable () async -> ProtectionScanner.Facts = { await ProtectionScanner.gather() }
    /// Opens a pane of System Settings.
    @ObservationIgnored var open: (URL) -> Void = { NSWorkspace.shared.open($0) }
    /// Reading takes a tenth of a second. The screen that says it is reading stays this long, so that
    /// it can be read itself instead of flashing by.
    @ObservationIgnored var shortestScan: Duration = .milliseconds(700)

    private(set) var phase: Phase = .idle
    private(set) var findings: [ProtectionFinding] = []
    /// When the findings were read. A setting changed since shows after the next scan.
    private(set) var scanned: Date?

    @ObservationIgnored private var task: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
    }

    // MARK: Scanning

    func startScan() {
        task?.cancel()
        findings = []
        phase = .scanning
        task = Task { [gather, shortestScan] in
            async let reading = gather()
            try? await Task.sleep(for: shortestScan)
            let facts = await reading
            guard !Task.isCancelled else { return }
            findings = ProtectionScanner.findings(from: facts)
            scanned = Date()
            phase = .results
            didScan()
        }
    }

    /// Reads the settings again without leaving the results, for when the user comes back from System
    /// Settings: what they switched on there has moved to where it belongs.
    func refresh() {
        guard phase == .results else { return }
        task?.cancel()
        task = Task { [gather] in
            let facts = await gather()
            guard !Task.isCancelled, phase == .results else { return }
            findings = ProtectionScanner.findings(from: facts)
            scanned = Date()
        }
    }

    func stop() {
        task?.cancel()
        phase = .idle
        didScan()
    }

    /// Forgets the check and goes back to the opening screen.
    func reset() {
        task?.cancel()
        findings = []
        phase = .idle
    }

    // MARK: What was found

    /// Whether the user said to leave this one as it is. It only counts while the check is not in place.
    func isAccepted(_ check: ProtectionCheck) -> Bool { settings.acceptedProtection.contains(check.rawValue) }

    /// What is off or weaker than it could be, and has not been waved through.
    var toLookAt: [ProtectionFinding] { findings.filter { $0.state == .needsLook && !isAccepted($0.check) } }
    /// What is off and stays off because the user said so.
    var accepted: [ProtectionFinding] { findings.filter { $0.state == .needsLook && isAccepted($0.check) } }
    var inPlace: [ProtectionFinding] { findings.filter { $0.state == .inPlace } }
    var unread: [ProtectionFinding] { findings.filter { $0.state == .unknown } }

    /// Stops counting a check that is off among what needs a look. It stays listed, and says why.
    func accept(_ check: ProtectionCheck) {
        guard !isAccepted(check) else { return }
        settings.acceptedProtection.append(check.rawValue)
    }

    func mentionAgain(_ check: ProtectionCheck) {
        settings.acceptedProtection.removeAll { $0 == check.rawValue }
    }

    /// Shows where the setting is changed. Changing it is left to the user.
    func openSettings(for finding: ProtectionFinding) {
        guard let url = finding.settings else { return }
        open(url)
    }

    // MARK: Demo

    /// Fills the model with made-up findings, so a screen can be looked at without asking this Mac.
    func showDemo(_ screen: String) {
        gather = { ProtectionDemoData.facts() }
        // The made-up screens open no window of System Settings over the user's work.
        open = { _ in }
        switch screen {
        case "intro":
            phase = .idle
        case "scanning":
            phase = .scanning
        case "scan":
            gather = { await ProtectionScanner.gather() }
            startScan()
        case "fine":
            findings = ProtectionScanner.findings(from: ProtectionDemoData.facts(allInPlace: true))
            scanned = Date()
            phase = .results
        default:
            findings = ProtectionScanner.findings(from: ProtectionDemoData.facts())
            scanned = Date()
            phase = .results
        }
    }
}
