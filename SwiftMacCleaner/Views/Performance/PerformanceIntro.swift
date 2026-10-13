//
//  PerformanceIntro.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Performance before a scan: what it covers, and the button that starts it.
struct PerformanceIntro: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let performance = model.performance
        IntroLayout {
            ModuleHero(.performance)
        } details: {
            IntroHeading(
                title: "Performance",
                detail: "Keep your Mac quick with the upkeep macOS leaves to you: a few maintenance tasks, and a look at what opens and runs on its own."
            )
            VStack(alignment: .leading, spacing: Design.Spacing.large) {
                ForEach(PerformanceModel.Section.allCases) { section in
                    FeatureBullet(glyph: Image(section.glyph), text: section.title)
                }
            }
            Text("Scanning only reads. Nothing runs or changes until you confirm, and tasks that need root ask for your password once.")
                .foregroundStyle(.quiet)
                .fixedSize(horizontal: false, vertical: true)
        }
        .orbAction {
            Button("Scan", action: performance.startScan)
                .buttonStyle(.orb)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("Scan for performance tasks")
                .help("Weigh up the maintenance tasks and list the login and background items")
        }
    }
}
