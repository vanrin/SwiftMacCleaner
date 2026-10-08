//
//  AppsScanning.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// Applications while it scans: how many apps are measured, and which one it is on.
struct AppsScanning: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let apps = model.apps
        let progress = apps.progress
        ActivityScreen(title: "Looking at your apps", detail: detail(progress)) {
            HeroOrb(progress: progress.fraction, isBusy: true) {
                OrbFigure(value: progress.done.formatted(), caption: "of \(progress.total.formatted()) apps")
            }
        }
        .orbAction {
            Button("Stop", action: apps.stop)
                .buttonStyle(.orb(progress: progress.fraction))
                .help("Stop looking and go back")
        }
    }

    private func detail(_ progress: AppScanProgress) -> String {
        if progress.isCheckingUpdates { return "Asking the update feeds which versions are current" }
        return progress.name.isEmpty ? "Listing the Applications folders" : "Measuring \(progress.name) and the files it keeps"
    }
}
