//
//  DuplicatesScanning.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Duplicates while it scans: first how many files it has looked at, then how many of the ones that
/// could be alike it has read.
struct DuplicatesScanning: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let duplicates = model.duplicates
        let progress = duplicates.progress
        let isComparing = progress.stage == .comparing
        ActivityScreen(title: isComparing ? "Comparing files" : "Looking through \(duplicates.scannedTitle)",
                       detail: progress.path.isEmpty ? " " : duplicates.displayPath(URL(fileURLWithPath: progress.path)), detailIsPath: true) {
            // How many files there are cannot be known up front, so the ring fills only once the comparing starts.
            HeroOrb(progress: isComparing ? progress.fraction : 0, isBusy: true) {
                if isComparing {
                    OrbFigure(value: progress.compared.formatted(), caption: "of \(progress.toCompare.formatted()) compared")
                } else {
                    OrbFigure(value: progress.filesSeen.formatted(), caption: "files")
                }
            }
        }
        .orbAction {
            Button("Stop", action: duplicates.stop)
                .buttonStyle(OrbButtonStyle(progress: isComparing ? progress.fraction : nil))
                .help("Stop looking and go back")
        }
    }
}
