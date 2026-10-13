//
//  AppsScanning.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Applications while it scans: how many apps are measured, and which one it is on.
struct AppsScanning: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let apps = model.apps
        let progress = apps.progress
        ActivityScreen(title: model.scanTitle(of: .apps), detail: progress.detail) {
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
}
