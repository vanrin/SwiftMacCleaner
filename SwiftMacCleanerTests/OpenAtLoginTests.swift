//
//  OpenAtLoginTests.swift
//  SwiftMacCleanerTests
//
//  Opening at login: what the switch shows for what macOS says, and how a launch macOS made at login
//  is guessed at before it is known.
//

import Foundation
import ServiceManagement
import Testing
@testable import SwiftMacCleaner

/// Stands in for macOS's service, so no test adds the app to the real list of items opened at login.
private final class FakeService: OpenAtLoginService, @unchecked Sendable {
    var status: SMAppService.Status
    /// What registering leads to: allowed at once, or waiting for the user.
    var afterRegistering = SMAppService.Status.enabled
    var failsWith: (any Error)?
    private(set) var calls: [String] = []

    init(_ status: SMAppService.Status = .notRegistered) {
        self.status = status
    }

    func register() throws {
        calls.append("register")
        if let failsWith { throw failsWith }
        status = afterRegistering
    }

    func unregister() throws {
        calls.append("unregister")
        if let failsWith { throw failsWith }
        status = .notRegistered
    }
}

@MainActor
struct OpenAtLoginTests {
    @Test func theSwitchShowsWhatMacOSSays() {
        #expect(OpenAtLogin.state(for: .enabled) == .on)
        #expect(OpenAtLogin.state(for: .requiresApproval) == .needsApproval)
        #expect(OpenAtLogin.state(for: .notRegistered) == .off)
        // An app that was never registered is sometimes reported this way.
        #expect(OpenAtLogin.state(for: .notFound) == .off)
        #expect(OpenAtLogin(service: FakeService(.enabled)).isOn)
        #expect(!OpenAtLogin(service: FakeService()).isOn)
    }

    @Test func switchingItOnRegistersAndOffTakesItAway() {
        let service = FakeService()
        let openAtLogin = OpenAtLogin(service: service)
        #expect(openAtLogin.state == .off)

        openAtLogin.set(true)
        #expect(service.calls == ["register"])
        #expect(openAtLogin.state == .on)
        #expect(openAtLogin.failure == nil)

        openAtLogin.set(false)
        #expect(service.calls == ["register", "unregister"])
        #expect(openAtLogin.state == .off)
    }

    @Test func staysOnWhileMacOSWaitsForTheUserToAllowIt() {
        let service = FakeService()
        service.afterRegistering = .requiresApproval
        let openAtLogin = OpenAtLogin(service: service)
        openAtLogin.set(true)
        #expect(openAtLogin.state == .needsApproval)
        #expect(openAtLogin.isOn)
        // Allowed in System Settings meanwhile: asking again finds out.
        service.status = .enabled
        openAtLogin.refresh()
        #expect(openAtLogin.state == .on)
        // And switched off there, behind the app's back.
        service.status = .notRegistered
        openAtLogin.refresh()
        #expect(!openAtLogin.isOn)
    }

    @Test func aChangeMacOSRefusesIsSaidAndTheSwitchStaysWhereItWas() {
        let service = FakeService()
        service.failsWith = NSError(domain: "SMAppServiceErrorDomain", code: 1,
                                    userInfo: [NSLocalizedDescriptionKey: "Operation not permitted"])
        let openAtLogin = OpenAtLogin(service: service)
        openAtLogin.set(true)
        #expect(openAtLogin.state == .off)
        #expect(openAtLogin.failure == "macOS did not add the app to the items opened at login: Operation not permitted")

        // The next change that goes through clears the message.
        service.failsWith = nil
        openAtLogin.set(true)
        #expect(openAtLogin.isOn)
        #expect(openAtLogin.failure == nil)
        service.failsWith = NSError(domain: "SMAppServiceErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "No"])
        openAtLogin.set(false)
        #expect(openAtLogin.isOn)
        #expect(openAtLogin.failure?.hasPrefix("macOS did not take the app off the items opened at login") == true)
    }
}

struct LoginLaunchTests {
    @Test func aLaunchIsTakenForTheLoginsOwnOnlyJustAfterLoggingIn() {
        let now = Date()
        func likely(registered: Bool = true, secondsAgo: TimeInterval?) -> Bool {
            LoginLaunch.isLikely(isRegistered: registered, sessionStart: secondsAgo.map { now.addingTimeInterval(-$0) }, now: now)
        }
        #expect(likely(secondsAgo: 5))
        #expect(likely(secondsAgo: 119))
        // Long after logging in, it is the user opening the app.
        #expect(!likely(secondsAgo: 121))
        #expect(!likely(secondsAgo: 3 * 86_400))
        // An app that is not set to open at login was not opened by the login.
        #expect(!likely(registered: false, secondsAgo: 5))
        // No record of logging in, or one from the future after the clock was set back: no guess is made.
        #expect(!likely(secondsAgo: nil))
        #expect(!likely(secondsAgo: -30))
    }

    @Test func readsWhenThisUserLoggedIn() {
        // Whoever runs the tests is logged in at the Mac, some time ago.
        if let start = LoginLaunch.sessionStart() {
            #expect(start <= Date())
            #expect(start > Date(timeIntervalSince1970: 0))
        }
        #expect(LoginLaunch.sessionStart(user: "nobody-\(UUID().uuidString)") == nil)
    }

    @Test func nothingIsPretendedOutsideADebugLaunch() {
        // The tests are not launched with the flags, so a launch is what macOS says it is.
        #expect(!LoginLaunch.pretendsGuess)
        #expect(!LoginLaunch.pretendsLogin)
        #expect(!LoginLaunch.wasMadeAtLogin)
    }
}
