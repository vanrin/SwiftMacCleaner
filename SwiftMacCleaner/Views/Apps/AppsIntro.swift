//
//  AppsIntro.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Applications before a scan: what it covers, and the button that starts it.
struct AppsIntro: View {
    @Environment(AppModel.self) private var model
    /// How many apps sit in the Applications folders, which listing them is enough to know.
    @State private var count: Int?

    var body: some View {
        let apps = model.apps
        IntroLayout {
            HeroOrb {
                if let count {
                    OrbFigure(value: count.formatted(), caption: count == 1 ? "app" : "apps")
                } else {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(Design.Typeface.orbFigure)
                        .accessibilityHidden(true)
                }
            }
        } details: {
            IntroHeading(
                title: "Applications",
                detail: "Take control of your apps. Uninstall them completely, see which have an update, and clear the installers and files they left behind."
            )
            VStack(alignment: .leading, spacing: Design.Spacing.large) {
                FeatureBullet(glyph: Image(.glyphUninstaller), text: "App Uninstaller")
                FeatureBullet(glyph: Image(.glyphUpdater), text: "App Updater")
                FeatureBullet(glyph: Image(.glyphLeftovers), text: "Leftovers and Installers")
            }
            Text("Scanning only reads. Nothing is removed until you confirm, and what is removed goes to the Trash, where it can be put back.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .orbAction {
            Button("Scan", action: apps.startScan)
                .buttonStyle(.orb)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("Scan applications")
                .help("Look at the installed apps, their updates and leftovers")
        }
        .task {
            count = AppScanner.bundles(in: AppScanner.applicationRoots(home: apps.home)).count
        }
    }
}
