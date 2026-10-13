//
//  OverviewScanning.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The overview while every part scans: a card for each part. The first part still at work stands
/// large and says what it is doing; the cards make room for the next as each finishes, and one
/// that is done shows what it found.
struct OverviewScanning: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let parts = model.overviewParts
        let done = parts.count { model.hasResults($0) && !model.isScanning($0) }
        let fraction = Double(done) / Double(max(parts.count, 1))
        let featured = model.featuredScan.flatMap { parts.firstIndex(of: $0) }
        GeometryReader { proxy in
            let frames = OverviewScanLayout.frames(count: parts.count, featured: featured, in: proxy.size,
                                                   spacing: Design.Spacing.large)
            ZStack(alignment: .topLeading) {
                ForEach(Array(zip(parts, frames)), id: \.0) { part, frame in
                    OverviewScanCard(part: part, isFeatured: part == model.featuredScan)
                        .frame(width: frame.width, height: frame.height)
                        .offset(x: frame.minX, y: frame.minY)
                }
            }
            .animation(reduceMotion ? nil : Design.Motion.scanCards, value: featured)
        }
        .pageLayout()
        .orbAction {
            Button("Stop", action: model.stopScan)
                .buttonStyle(.orb(progress: fraction))
                .help("Stop every part and show what was found so far")
        }
    }
}
