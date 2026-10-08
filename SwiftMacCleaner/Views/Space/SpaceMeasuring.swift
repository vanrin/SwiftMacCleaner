//
//  SpaceMeasuring.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Largest Folders while it measures: how much it has counted, and where it is looking.
struct SpaceMeasuring: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let space = model.space
        ActivityScreen(title: "Measuring \(space.rootTitle)", detail: space.displayPath(space.progress.path), detailIsPath: true) {
            // How long a folder tree takes cannot be known up front, so the ring stays empty and the glow breathes.
            HeroOrb(progress: 0, isBusy: true) {
                OrbFigure(value: ByteFormat.string(space.progress.measured), caption: "\(space.progress.items.formatted()) items")
            }
        }
        .orbAction {
            Button("Stop", action: space.stop)
                .buttonStyle(.orb)
                .help("Stop measuring")
        }
    }
}
