//
//  CleaningView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Shown while a clean-up runs, or the overview's run goes through its parts.
struct CleaningView: View {
    let progress: CleanProgress

    var body: some View {
        ActivityScreen(title: "Cleaning", detail: progress.status) {
            HeroOrb(progress: progress.fraction, isBusy: true) {
                OrbFigure(value: progress.fraction.formatted(.percent.precision(.fractionLength(0))), caption: "done")
            }
        }
    }
}
