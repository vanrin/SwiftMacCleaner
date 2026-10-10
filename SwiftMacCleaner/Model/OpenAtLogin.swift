//
//  OpenAtLogin.swift
//  SwiftMacCleaner
//

import Observation
import ServiceManagement

/// What registers the app to open at login: macOS's own service in the app, a stand-in in the tests.
nonisolated protocol OpenAtLoginService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: OpenAtLoginService {}

/// Whether macOS opens the app when the user logs in.
///
/// macOS keeps the answer, and shows it under Login Items in System Settings, where it can be changed
/// without this app knowing. So the answer is asked for each time it is shown, never remembered.
@Observable
final class OpenAtLogin {
    enum State: Equatable {
        case off, on
        /// Registered, and waiting for the user to allow it in System Settings.
        case needsApproval
    }

    private(set) var state: State = .off
    /// What macOS said when the last change did not go through, for the line under the switch.
    private(set) var failure: String?
    @ObservationIgnored private let service: any OpenAtLoginService

    init(service: any OpenAtLoginService = SMAppService.mainApp) {
        self.service = service
        refresh()
    }

    /// Whether the switch is on. It is on while macOS waits for approval too: the asking has been done.
    var isOn: Bool { state != .off }

    /// Asks macOS again, for when the user may have changed it in System Settings meanwhile.
    func refresh() {
        state = Self.state(for: service.status)
    }

    func set(_ isOn: Bool) {
        do {
            if isOn { try service.register() } else { try service.unregister() }
            failure = nil
        } catch {
            failure = "macOS did not \(isOn ? "add the app to" : "take the app off") the items opened at login: \(error.localizedDescription)"
        }
        refresh()
    }

    /// Opens Login Items in System Settings, where a waiting item is allowed.
    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    static func state(for status: SMAppService.Status) -> State {
        switch status {
        case .enabled: .on
        case .requiresApproval: .needsApproval
        // An app that was never registered is sometimes reported as not found rather than not registered.
        case .notRegistered, .notFound: .off
        @unknown default: .off
        }
    }
}
