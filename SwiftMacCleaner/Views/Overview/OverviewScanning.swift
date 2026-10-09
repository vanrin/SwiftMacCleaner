//
//  OverviewScanning.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The overview while every part scans: how many are done, which are under way, and what the clean-ups
/// have found so far.
struct OverviewScanning: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let parts = model.overviewParts
        let done = parts.count { model.hasResults($0) && !model.isScanning($0) }
        let fraction = Double(done) / Double(max(parts.count, 1))
        ActivityScreen(title: "Scanning \(model.disk.name)", detail: detail(parts: parts, done: done)) {
            HeroOrb(progress: fraction, isBusy: true) {
                OrbFigure(value: ByteFormat.string(model.foundSize), caption: "found so far")
            }
        }
        .orbAction {
            Button("Stop", action: model.stopScan)
                .buttonStyle(.orb(progress: fraction))
                .help("Stop every part and show what was found so far")
        }
    }

    /// The parts scanning right now, and how many are done.
    private func detail(parts: [SidebarItem], done: Int) -> String {
        let progress = "\(done) of \(parts.count) parts done"
        let current = parts.filter(model.isScanning).map(\.title)
        guard !current.isEmpty else { return progress }
        return "\(current.formatted(.list(type: .and, width: .narrow))) · \(progress)"
    }
}
