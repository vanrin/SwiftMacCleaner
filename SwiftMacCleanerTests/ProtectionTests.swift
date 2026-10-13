//
//  ProtectionTests.swift
//  SwiftMacCleanerTests
//
//  The Protection screen: how what macOS's own tools print is read, when a setting is said to need a
//  look, and what the user can do about one. No tool is run here and no setting is read: the answers
//  are made up.
//

import Foundation
import Testing
@testable import SwiftMacCleaner

private func said(_ stdout: String, stderr: String = "", status: Int32 = 0, timedOut: Bool = false) -> Shell.Output {
    Shell.Output(status: status, stdout: stdout, stderr: stderr, timedOut: timedOut)
}

private func finding(_ check: ProtectionCheck, in findings: [ProtectionFinding]) -> ProtectionFinding {
    findings.first { $0.check == check }!
}

struct ProtectionScannerTests {
    @Test func readsFileVaultWhileItIsBeingSwitchedToo() {
        #expect(ProtectionScanner.fileVault(said("FileVault is On.")) == ProtectionFinding(check: .fileVault, state: .inPlace, status: "On"))
        let off = ProtectionScanner.fileVault(said("FileVault is Off."))
        #expect(off.state == .needsLook)
        #expect(off.status == "Off")
        #expect(off.advice?.contains("recovery key") == true)
        #expect(off.settings?.absoluteString == "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?FileVault")
        // Halfway there counts by where it is going.
        let encrypting = ProtectionScanner.fileVault(said("FileVault is Off.\nEncryption in progress: Percent completed = 41"))
        #expect(encrypting.state == .inPlace)
        #expect(encrypting.status == "Being switched on")
        let decrypting = ProtectionScanner.fileVault(said("FileVault is On.\nDecryption in progress: Percent completed = 12"))
        #expect(decrypting.state == .needsLook)
        #expect(decrypting.status == "Being switched off")
        #expect(ProtectionScanner.fileVault(said("fdesetup: something new")).state == .unknown)
        #expect(ProtectionScanner.fileVault(nil).state == .unknown)
        #expect(ProtectionScanner.fileVault(said("FileVault is On.", timedOut: true)).state == .unknown)
    }

    @Test func readsHowSoonThePasswordIsAskedFor() {
        // What the tool really prints, on the channel for errors and with the time in front.
        let real = said("", stderr: "2026-10-13 10:31:22.076 sysadminctl[18352:3527271] screenLock delay is 300 seconds")
        let fiveMinutes = ProtectionScanner.screenLock(real, automaticLogin: nil)
        #expect(fiveMinutes == ProtectionFinding(check: .screenLock, state: .inPlace, status: "Password required after 5 minutes"))
        #expect(ProtectionScanner.screenLock(said("", stderr: "screenLock delay is immediate"), automaticLogin: nil).status == "Password required at once")
        #expect(ProtectionScanner.screenLock(said("", stderr: "screenLock delay is 0.000000 seconds"), automaticLogin: nil).status == "Password required at once")
        #expect(ProtectionScanner.screenLock(said("", stderr: "screenLock delay is 5 seconds"), automaticLogin: nil).status == "Password required after 5 seconds")
        // A quarter of an hour is the longest that passes.
        #expect(ProtectionScanner.screenLock(said("", stderr: "screenLock delay is 900 seconds"), automaticLogin: nil).state == .inPlace)
        let late = ProtectionScanner.screenLock(said("", stderr: "screenLock delay is 14400.000000 seconds"), automaticLogin: nil)
        #expect(late.state == .needsLook)
        #expect(late.status == "Password required only after 4 hours")
        let never = ProtectionScanner.screenLock(said("", stderr: "screenLock is off"), automaticLogin: nil)
        #expect(never.state == .needsLook)
        #expect(never.status == "No password after sleep")
        #expect(never.settings?.absoluteString == "x-apple.systempreferences:com.apple.Lock-Screen-Settings.extension")

        // Logging in by itself undoes a lock, however strict, and is changed somewhere else.
        let open = ProtectionScanner.screenLock(said("", stderr: "screenLock delay is immediate"), automaticLogin: "demo")
        #expect(open.state == .needsLook)
        #expect(open.status == "Logs in as demo without a password")
        #expect(open.settings?.absoluteString == "x-apple.systempreferences:com.apple.Users-Groups-Settings.extension")
        #expect(ProtectionScanner.screenLock(nil, automaticLogin: "").state == .unknown)
        #expect(ProtectionScanner.screenLock(said("", stderr: "sysadminctl: unknown option"), automaticLogin: nil).state == .unknown)
    }

    @Test func readsGatekeeperAndSystemIntegrityProtection() {
        #expect(ProtectionScanner.gatekeeper(said("assessments enabled")) == ProtectionFinding(check: .gatekeeper, state: .inPlace, status: "On"))
        // The tool says "disabled" with a status of its own, which is not a failure to read.
        let off = ProtectionScanner.gatekeeper(said("assessments disabled", status: 1))
        #expect(off.state == .needsLook)
        #expect(off.status == "Off")
        #expect(off.settings?.absoluteString == "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Security")
        #expect(ProtectionScanner.gatekeeper(said("")).state == .unknown)

        #expect(ProtectionScanner.systemIntegrity(said("System Integrity Protection status: enabled.")).state == .inPlace)
        let disabled = ProtectionScanner.systemIntegrity(said("System Integrity Protection status: disabled."))
        #expect(disabled.state == .needsLook)
        #expect(disabled.status == "Off")
        #expect(disabled.advice?.contains("csrutil enable") == true)
        // It is changed from Recovery, so there is no pane to open.
        #expect(disabled.settings == nil)
        let partly = ProtectionScanner.systemIntegrity(said("""
        System Integrity Protection status: enabled (Custom Configuration).

        Configuration:
            Kext Signing: disabled
        """))
        #expect(partly.state == .needsLook)
        #expect(partly.status == "Partly switched off")
        #expect(ProtectionScanner.systemIntegrity(said("System Integrity Protection status: unknown (Custom Configuration).")).status == "Partly switched off")
        let unread = ProtectionScanner.systemIntegrity(nil)
        #expect(unread.state == .unknown)
        #expect(unread.advice?.contains("Nothing was changed") == true)
    }

    @Test func readsTheFirewallInItsThreeStates() {
        #expect(ProtectionScanner.firewall(said("Firewall is enabled. (State = 1)")) == ProtectionFinding(check: .firewall, state: .inPlace, status: "On"))
        #expect(ProtectionScanner.firewall(said("Firewall is blocking all non-essential incoming connections. (State = 2)")).status
            == "On, blocking all incoming connections")
        let off = ProtectionScanner.firewall(said("Firewall is disabled. (State = 0)"))
        #expect(off.state == .needsLook)
        #expect(off.status == "Off")
        #expect(off.settings?.absoluteString == "x-apple.systempreferences:com.apple.Network-Settings.extension?Firewall")
        #expect(ProtectionScanner.firewall(said("usage: socketfilterfw", status: 1)).state == .unknown)
    }

    @Test func malwareDefinitionsAreStaleOnlyWhenNoneHaveArrivedForMonths() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let fresh = ProtectionScanner.Definitions(version: "5366", updated: now.addingTimeInterval(-4 * 86_400))
        #expect(ProtectionScanner.malwareDefinitions(fresh, now: now)
            == ProtectionFinding(check: .malwareDefinitions, state: .inPlace, status: "Version 5366, updated 4 days ago"))
        let old = ProtectionScanner.Definitions(version: "5290", updated: now.addingTimeInterval(-96 * 86_400))
        let stale = ProtectionScanner.malwareDefinitions(old, now: now)
        #expect(stale.state == .needsLook)
        #expect(stale.status == "Version 5290, updated 3 months ago")
        #expect(stale.advice?.contains("Install Security Responses and system files") == true)
        // Without a date there is nothing to judge by, and without a list nothing to say.
        #expect(ProtectionScanner.malwareDefinitions(ProtectionScanner.Definitions(version: "5366", updated: nil), now: now).status == "Version 5366")
        #expect(ProtectionScanner.malwareDefinitions(nil, now: now).state == .unknown)

        // Of the two places macOS keeps a list, the newer one counts.
        let folder = FileManager.default.temporaryDirectory.appending(path: "mdc-protection-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        func bundle(_ name: String, version: String, age days: Double) throws -> String {
            let info = folder.appending(path: "\(name)/XProtect.bundle/Contents/Info.plist")
            try FileManager.default.createDirectory(at: info.deletingLastPathComponent(), withIntermediateDirectories: true)
            try PropertyListSerialization.data(fromPropertyList: ["CFBundleShortVersionString": version], format: .xml, options: 0).write(to: info)
            try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-days * 86_400)], ofItemAtPath: info.path)
            return info.deletingLastPathComponent().deletingLastPathComponent().path
        }
        let shipped = try bundle("system", version: "5290", age: 200)
        let updated = try bundle("updates", version: "5366", age: 3)
        let found = try #require(ProtectionScanner.definitions(in: [shipped, updated, folder.appending(path: "missing").path]))
        #expect(found.version == "5366")
        #expect(abs((found.updated?.timeIntervalSinceNow ?? 0) + 3 * 86_400) < 60)
        #expect(ProtectionScanner.definitions(in: [folder.appending(path: "missing").path]) == nil)
    }

    @Test func automaticUpdatesCountAsOnUnlessSwitchedOff() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        // A switch nobody has touched is as Apple ships it.
        #expect(ProtectionScanner.updates([:], lastCheck: nil, now: now)
            == ProtectionFinding(check: .updates, state: .inPlace, status: "Installs security updates on its own"))
        let all = ProtectionScanner.updates([ProtectionScanner.installsSystemUpdates: true, ProtectionScanner.installsSecurityData: true],
                                            lastCheck: now.addingTimeInterval(-2 * 86_400), now: now)
        #expect(all.status == "Installs security and macOS updates on its own, last checked 2 days ago")
        // Leaving macOS updates to be installed by hand is a preference, not a gap.
        #expect(ProtectionScanner.updates([ProtectionScanner.installsSystemUpdates: false], lastCheck: nil, now: now).state == .inPlace)

        let unchecked = ProtectionScanner.updates([ProtectionScanner.checksForUpdates: false], lastCheck: nil, now: now)
        #expect(unchecked.state == .needsLook)
        #expect(unchecked.status == "Not checking for updates")
        for key in [ProtectionScanner.installsSecurityData, ProtectionScanner.installsCriticalUpdates] {
            let byHand = ProtectionScanner.updates([key: false, ProtectionScanner.installsSystemUpdates: true], lastCheck: nil, now: now)
            #expect(byHand.state == .needsLook)
            #expect(byHand.status == "Security updates wait to be installed by hand")
            #expect(byHand.settings?.absoluteString == "x-apple.systempreferences:com.apple.Software-Update-Settings.extension")
        }
    }

    @Test func remoteAccessIsWhatOtherComputersCanReach() {
        let listing = """
        Active Internet connections (including servers)
        Proto Recv-Q Send-Q  Local Address          Foreign Address        (state)
        tcp4       0      0  192.168.1.20.52011     17.57.146.20.5223      ESTABLISHED
        tcp46      0      0  *.3000                 *.*                    LISTEN
        tcp4       0      0  127.0.0.1.5900         *.*                    LISTEN
        tcp6       0      0  ::1.445                *.*                    LISTEN
        tcp6       0      0  fe80::1%lo0.3031       *.*                    LISTEN
        tcp4       0      0  127.0.0.1.11434        *.*                    LISTEN
        """
        // Listening, but only to this Mac itself.
        #expect(ProtectionScanner.openPorts(in: listing) == [3000])
        #expect(ProtectionScanner.sharing(said(listing)) == ProtectionFinding(check: .sharing, state: .inPlace, status: "Off"))

        let one = ProtectionScanner.sharing(said(listing + "\ntcp46      0      0  *.22                   *.*                    LISTEN"))
        #expect(one.state == .needsLook)
        #expect(one.status == "Remote Login is on")
        #expect(one.advice?.contains("can use it") == true)
        #expect(one.settings?.absoluteString == "x-apple.systempreferences:com.apple.Sharing-Settings.extension")

        // In the order they are listed in System Settings, each once, whichever address it listens on.
        let several = ProtectionScanner.sharing(said("""
        tcp4       0      0  *.445                  *.*                    LISTEN
        tcp6       0      0  *.445                  *.*                    LISTEN
        tcp4       0      0  *.548                  *.*                    LISTEN
        tcp4       0      0  192.168.1.20.5900      *.*                    LISTEN
        tcp46      0      0  *.22                   *.*                    LISTEN
        tcp4       0      0  *.3031                 *.*                    LISTEN
        """))
        #expect(several.status == "Remote Login, Screen Sharing, File Sharing and Remote Apple Events are on")
        #expect(several.advice?.contains("can use them") == true)
        #expect(ProtectionScanner.sharing(nil).state == .unknown)
        #expect(ProtectionScanner.sharing(said("", status: 1)).state == .unknown)
    }

    @Test func everyCheckIsReportedOnceInItsOrder() {
        let findings = ProtectionScanner.findings(from: ProtectionDemoData.facts())
        #expect(findings.map(\.check) == ProtectionCheck.allCases)
        #expect(findings.filter { $0.state == .needsLook }.map(\.check) == [.malwareDefinitions, .firewall, .sharing])
        #expect(ProtectionScanner.findings(from: ProtectionDemoData.facts(allInPlace: true)).allSatisfy { $0.state == .inPlace })
        // A Mac that answers nothing is not said to be unprotected.
        let silent = ProtectionScanner.findings(from: ProtectionScanner.Facts())
        #expect(finding(.updates, in: silent).state == .inPlace)
        #expect(silent.filter { $0.check != .updates }.allSatisfy { $0.state == .unknown })
        #expect(silent.allSatisfy { $0.state != .needsLook })

        // Each has a name, a reason and a symbol, and all but one a place where it is changed.
        #expect(Set(ProtectionCheck.allCases.map(\.title)).count == ProtectionCheck.allCases.count)
        #expect(ProtectionCheck.allCases.allSatisfy { !$0.purpose.isEmpty && !$0.symbol.isEmpty })
        #expect(ProtectionCheck.allCases.filter { $0.settings == nil } == [.systemIntegrity])
        #expect(ProtectionCheck.allCases.compactMap(\.settings).allSatisfy { $0.scheme == "x-apple.systempreferences" })
    }
}

@MainActor
struct ProtectionModelTests {
    /// Settings kept apart from the user's own, so what a test accepts never reaches them.
    private func settings() throws -> (AppSettings, () -> Void) {
        let (settings, _, forget) = try stored()
        return (settings, forget)
    }

    /// The same, with the store behind them, for a test that reads them back as a later launch would.
    private func stored() throws -> (AppSettings, UserDefaults, () -> Void) {
        let name = "ProtectionTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        return (AppSettings(defaults: defaults), defaults, { defaults.removePersistentDomain(forName: name) })
    }

    private func scanned(_ protection: ProtectionModel) async throws {
        for _ in 0..<200 where protection.phase == .scanning { try await Task.sleep(for: .milliseconds(10)) }
    }

    @Test func aCheckReadsTheSettingsAndSortsThem() async throws {
        let (settings, forget) = try settings()
        defer { forget() }
        let protection = ProtectionModel(settings: settings)
        protection.gather = { ProtectionDemoData.facts() }
        protection.shortestScan = .zero
        var scans = 0
        protection.didScan = { scans += 1 }
        #expect(protection.phase == .idle)

        protection.startScan()
        #expect(protection.phase == .scanning)
        try await scanned(protection)
        #expect(protection.phase == .results)
        #expect(scans == 1)
        #expect(protection.findings.count == 8)
        #expect(protection.toLookAt.map(\.check) == [.malwareDefinitions, .firewall, .sharing])
        #expect(protection.inPlace.count == 5)
        #expect(protection.accepted.isEmpty)
        #expect(protection.unread.isEmpty)
        #expect(protection.scanned != nil)

        // Back from System Settings with the firewall on and Remote Login off: the list says so, and
        // nobody is told a scan ended, because none was started.
        protection.gather = { ProtectionDemoData.facts(allInPlace: true) }
        protection.refresh()
        for _ in 0..<200 where !protection.toLookAt.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        #expect(protection.phase == .results)
        #expect(protection.toLookAt.isEmpty)
        #expect(protection.inPlace.count == 8)
        #expect(scans == 1)

        // Stopped, it goes back to the start and whoever waits is told. Nothing is read again from there.
        protection.gather = {
            try? await Task.sleep(for: .seconds(5))
            return ProtectionDemoData.facts()
        }
        protection.startScan()
        protection.stop()
        #expect(protection.phase == .idle)
        #expect(scans == 2)
        protection.refresh()
        #expect(protection.phase == .idle)
    }

    @Test func aSettingLeftOffOnPurposeStopsCountingAndStaysListed() async throws {
        let (settings, defaults, forget) = try stored()
        defer { forget() }
        let protection = ProtectionModel(settings: settings)
        protection.showDemo("results")
        #expect(protection.toLookAt.count == 3)

        protection.accept(.firewall)
        protection.accept(.firewall)
        #expect(settings.acceptedProtection == ["firewall"])
        #expect(protection.isAccepted(.firewall))
        #expect(protection.toLookAt.map(\.check) == [.malwareDefinitions, .sharing])
        #expect(protection.accepted.map(\.check) == [.firewall])
        #expect(protection.findings.count == 8)

        // It is remembered for the next launch, and only matters while the setting is off.
        let later = ProtectionModel(settings: AppSettings(defaults: defaults))
        later.showDemo("fine")
        #expect(later.isAccepted(.firewall))
        #expect(later.accepted.isEmpty)
        #expect(later.toLookAt.isEmpty)
        #expect(later.inPlace.count == 8)

        protection.mentionAgain(.firewall)
        #expect(settings.acceptedProtection.isEmpty)
        #expect(protection.toLookAt.count == 3)
    }

    @Test func aRowLeadsToWhereItsSettingIsChangedAndChangesNothingItself() throws {
        let (settings, forget) = try settings()
        defer { forget() }
        let protection = ProtectionModel(settings: settings)
        protection.showDemo("results")
        var opened: [URL] = []
        protection.open = { opened.append($0) }

        protection.openSettings(for: finding(.firewall, in: protection.findings))
        protection.openSettings(for: finding(.fileVault, in: protection.findings))
        // The one that is changed from Recovery has nowhere to lead.
        protection.openSettings(for: finding(.systemIntegrity, in: protection.findings))
        #expect(opened.map(\.absoluteString) == [
            "x-apple.systempreferences:com.apple.Network-Settings.extension?Firewall",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?FileVault",
        ])
    }

    @Test func theSidebarAndTheOverviewSayHowManyNeedALook() throws {
        let (settings, forget) = try settings()
        defer { forget() }
        let model = AppModel(home: URL(fileURLWithPath: "/Users/demo", isDirectory: true), settings: settings)
        #expect(model.overviewParts.contains(.protection))
        #expect(model.sidebarStatus(of: .protection) == SidebarStatus())
        #expect(!model.hasResults(.protection))

        model.protection.showDemo("results")
        #expect(model.sidebarStatus(of: .protection) == SidebarStatus(badge: "3 to check", hasFindings: true))
        #expect(model.hasResults(.protection))
        // Nothing here is the app's to change, so Run has nothing to do for it.
        #expect(!model.hasWork(.protection))
        model.protection.accept(.malwareDefinitions)
        model.protection.accept(.firewall)
        model.protection.accept(.sharing)
        #expect(model.sidebarStatus(of: .protection) == SidebarStatus(badge: "Fine"))

        model.protection.showDemo("scanning")
        #expect(model.isScanning(.protection))
        #expect(model.sidebarStatus(of: .protection) == SidebarStatus(badge: "Scanning"))
    }
}
