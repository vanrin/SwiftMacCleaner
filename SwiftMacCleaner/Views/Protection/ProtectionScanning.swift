//
//  ProtectionScanning.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Protection while it reads the settings, which takes a moment.
struct ProtectionScanning: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ActivityScreen(title: model.scanTitle(of: .protection), detail: model.scanDetail(of: .protection)) {
            ModuleHero(.protection, isBusy: true)
        }
        .orbAction {
            Button("Stop", action: model.protection.stop)
                .buttonStyle(.orb)
                .help("Stop reading and go back")
        }
    }
}
