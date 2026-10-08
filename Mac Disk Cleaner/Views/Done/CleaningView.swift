//
//  CleaningView.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// Shown while the clean-up runs.
struct CleaningView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let progress = model.cleanProgress
        ActivityScreen(title: "Cleaning", detail: progress.status) {
            HeroOrb(progress: progress.fraction, isBusy: true) {
                OrbFigure(value: progress.fraction.formatted(.percent.precision(.fractionLength(0))), caption: "done")
            }
        }
    }
}
