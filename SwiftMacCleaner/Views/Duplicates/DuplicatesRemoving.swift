//
//  DuplicatesRemoving.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Shown while duplicates are being moved to the Trash.
struct DuplicatesRemoving: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let progress = model.duplicates.removeProgress
        ActivityScreen(title: "Removing duplicates", detail: progress.status) {
            HeroOrb(progress: progress.fraction, isBusy: true) {
                OrbFigure(value: progress.fraction.formatted(.percent.precision(.fractionLength(0))), caption: "done")
            }
        }
    }
}
