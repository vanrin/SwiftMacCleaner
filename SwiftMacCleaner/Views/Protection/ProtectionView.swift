//
//  ProtectionView.swift
//  SwiftMacCleaner
//

import AppKit
import SwiftUI

/// Protection: how this Mac's own defences are set. It has a check of its own, which only reads; what
/// it finds is changed in System Settings, by the user.
struct ProtectionView: View {
    @Environment(AppModel.self) private var model
    @State private var isStartingOver = false

    var body: some View {
        let protection = model.protection
        Group {
            switch protection.phase {
            case .idle:
                ProtectionIntro()
            case .scanning:
                ProtectionScanning()
            case .results:
                ProtectionResults()
            }
        }
        // Back from System Settings, where something may have been switched on.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            protection.refresh()
        }
        .confirmsStartingOver($isStartingOver, from: .protection, in: model)
        .toolbar {
            if protection.phase == .results {
                ToolbarItem {
                    StartOverButton(isAsking: $isStartingOver)
                        .help("Forget this check and go back to the start of Protection")
                }
            }
        }
    }
}
