//
//  PerformanceScanning.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Performance while it scans: which of its three looks is under way.
struct PerformanceScanning: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let performance = model.performance
        ActivityScreen(title: "Examining your Mac", detail: performance.progress) {
            HeroOrb(isBusy: true) {
                Image(systemName: "bolt.fill")
                    .font(Design.Typeface.orbFigure)
                    .accessibilityHidden(true)
            }
        }
        .orbAction {
            Button("Stop", action: performance.stop)
                .buttonStyle(.orb)
                .help("Stop looking and go back")
        }
    }
}
