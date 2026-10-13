//
//  ProtectionIntro.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Protection before a check: what it looks at, and the button that starts it.
struct ProtectionIntro: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let protection = model.protection
        IntroLayout {
            HeroOrb {
                Image(systemName: "checkmark.shield.fill")
                    .font(Design.Typeface.orbFigure)
                    .accessibilityHidden(true)
            }
        } details: {
            IntroHeading(
                title: "Protection",
                detail: "See whether the defences macOS comes with are switched on: the ones that guard what is on this Mac, what runs on it, and who can reach it."
            )
            VStack(alignment: .leading, spacing: Design.Spacing.large) {
                FeatureBullet(glyph: Image(systemName: "lock.fill"), text: "Your disk and login")
                FeatureBullet(glyph: Image(systemName: "checkmark.seal.fill"), text: "Apps and the system")
                FeatureBullet(glyph: Image(systemName: "network"), text: "The network")
            }
            Text("Checking only reads, and asks for no password. Nothing is changed from here: each setting is yours to change in System Settings.")
                .foregroundStyle(.quiet)
                .fixedSize(horizontal: false, vertical: true)
        }
        .orbAction {
            Button("Scan", action: protection.startScan)
                .buttonStyle(.orb)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("Check this Mac's protection")
                .help("Read how this Mac's defences are set. Nothing is changed.")
        }
    }
}
