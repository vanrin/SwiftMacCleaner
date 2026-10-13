//
//  ProtectionScanning.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Protection while it reads the settings, which takes a moment.
struct ProtectionScanning: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ActivityScreen(title: "Checking your Mac's protection", detail: "Reading how its defences are set") {
            HeroOrb(isBusy: true) {
                Image(systemName: "checkmark.shield.fill")
                    .font(Design.Typeface.orbFigure)
                    .accessibilityHidden(true)
            }
        }
        .orbAction {
            Button("Stop", action: model.protection.stop)
                .buttonStyle(.orb)
                .help("Stop reading and go back")
        }
    }
}
