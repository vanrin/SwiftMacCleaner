//
//  AppsRemoving.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// Shown while apps or leftovers are being moved to the Trash.
struct AppsRemoving: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let apps = model.apps
        let progress = apps.removeProgress
        ActivityScreen(title: apps.removesLeftovers ? "Removing leftovers" : "Uninstalling", detail: progress.status) {
            HeroOrb(progress: progress.fraction, isBusy: true) {
                OrbFigure(value: progress.fraction.formatted(.percent.precision(.fractionLength(0))), caption: "done")
            }
        }
    }
}
