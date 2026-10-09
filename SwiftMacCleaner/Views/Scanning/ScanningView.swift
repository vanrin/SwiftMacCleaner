//
//  ScanningView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Progress while the areas are being measured. The sidebar shows how each area is doing.
struct ScanningView: View {
    @Environment(AppModel.self) private var model
    @Environment(CleanUpModel.self) private var cleanUp
    /// What the screen says it is doing. Without one, it names the disk.
    var title: String?

    var body: some View {
        let areas = cleanUp.scannedAreas
        let fraction = Double(cleanUp.finishedAreaCount) / Double(max(areas.count, 1))
        ActivityScreen(title: title ?? "Scanning \(model.disk.name)", detail: detail(areas)) {
            HeroOrb(progress: fraction, isBusy: true) {
                OrbFigure(value: ByteFormat.string(cleanUp.foundSize), caption: "found so far")
            }
        }
        .orbAction {
            Button("Stop", action: cleanUp.stopScan)
                .buttonStyle(.orb(progress: fraction))
                .help("Stop scanning and show what was found so far")
        }
    }

    /// The areas being measured right now, and how many are done.
    private func detail(_ areas: [Area]) -> String {
        let progress = "\(cleanUp.finishedAreaCount) of \(areas.count) areas done"
        let current = areas.filter { cleanUp.areaState(for: $0) == .scanning }.map(\.title)
        guard !current.isEmpty else { return progress }
        return "\(current.formatted(.list(type: .and, width: .narrow))) · \(progress)"
    }
}
