//
//  PerformanceRunning.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Shown while tasks run or items are removed.
struct PerformanceRunning: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let performance = model.performance
        let progress = performance.runProgress
        ActivityScreen(title: performance.section == .maintenance ? "Running tasks" : "Removing items", detail: progress.status) {
            HeroOrb(progress: progress.fraction, isBusy: true) {
                OrbFigure(value: progress.fraction.formatted(.percent.precision(.fractionLength(0))), caption: "done")
            }
        }
    }
}
