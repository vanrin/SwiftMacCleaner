//
//  ScanningView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Progress while the areas are being measured. The sidebar shows how each area is doing.
struct ScanningView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let areas = model.scannedAreas
        let fraction = Double(model.finishedAreaCount) / Double(max(areas.count, 1))
        ActivityScreen(title: "Scanning \(model.disk.name)", detail: detail(areas)) {
            HeroOrb(progress: fraction, isBusy: true) {
                OrbFigure(value: ByteFormat.string(model.foundSize), caption: "found so far")
            }
        }
        .orbAction {
            Button("Stop", action: model.stopScan)
                .buttonStyle(.orb(progress: fraction))
                .help("Stop scanning and show what was found so far")
        }
    }

    /// The areas being measured right now, and how many are done.
    private func detail(_ areas: [Area]) -> String {
        let progress = "\(model.finishedAreaCount) of \(areas.count) areas done"
        let current = areas.filter { model.areaState(for: $0) == .scanning }.map(\.title)
        guard !current.isEmpty else { return progress }
        return "\(current.formatted(.list(type: .and, width: .narrow))) · \(progress)"
    }
}
