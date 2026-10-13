//
//  OverviewScanTests.swift
//  SwiftMacCleanerTests
//
//  The cards of the overview's scan: where they stand, which one is shown at work, and what each says.
//

import CoreGraphics
import Foundation
import Testing
@testable import SwiftMacCleaner

@MainActor
struct OverviewScanTests {
    private func temporaryHome() throws -> URL {
        let home = FileManager.default.temporaryDirectory.appending(path: "mdc-scan-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        return home
    }

    private func finding(id: String, area: Area, size: Int64) -> Finding {
        Finding(id: id, area: area, aftermath: .rebuilds, title: id, summary: "", explanation: "", method: .delete, actionTarget: "",
                items: [FindingItem(id: "\(id)/1", title: "", detail: "", size: size)])
    }

    @Test func theCardsStandInTwoRowsOnceThereAreMoreThanThree() {
        #expect((1...6).map(OverviewScanLayout.cardsPerRow) == [1, 2, 3, 2, 3, 3])
        #expect(OverviewScanLayout.frames(count: 0, featured: nil, in: CGSize(width: 900, height: 500), spacing: 16).isEmpty)
    }

    @Test func theCardAtWorkIsWiderAndItsRowTaller() {
        let size = CGSize(width: 1000, height: 600)
        let frames = OverviewScanLayout.frames(count: 6, featured: 1, in: size, spacing: 16)
        #expect(frames.count == 6)

        // Two rows of three. The row with the card at work takes the taller share of the height.
        let tall = (600.0 - 16) * 2.3 / 3.3
        for frame in frames[0..<3] { #expect(abs(frame.height - tall) < 0.01 && frame.minY == 0) }
        for frame in frames[3..<6] { #expect(abs(frame.height - (600 - 16 - tall)) < 0.01 && abs(frame.minY - (tall + 16)) < 0.01) }

        // In that row the card at work is 2.8 times as wide as the two beside it; the other row shares evenly.
        let narrow = (1000.0 - 32) / 4.8
        #expect(abs(frames[0].width - narrow) < 0.01)
        #expect(abs(frames[1].width - narrow * 2.8) < 0.01)
        #expect(abs(frames[1].minX - (narrow + 16)) < 0.01)
        #expect(abs(frames[2].maxX - 1000) < 0.01)
        for frame in frames[3..<6] { #expect(abs(frame.width - (1000.0 - 32) / 3) < 0.01) }
        #expect(abs(frames[5].maxX - 1000) < 0.01 && abs(frames[5].maxY - 600) < 0.01)

        // No card overlaps another.
        for (index, frame) in frames.enumerated() {
            for other in frames[(index + 1)...] { #expect(!frame.intersects(other.insetBy(dx: 0.01, dy: 0.01))) }
        }

        // The work moves to the second row, and the rows change places in height.
        let later = OverviewScanLayout.frames(count: 6, featured: 5, in: size, spacing: 16)
        #expect(abs(later[0].height - (600 - 16 - tall)) < 0.01)
        #expect(abs(later[5].height - tall) < 0.01)
        #expect(abs(later[5].width - narrow * 2.8) < 0.01)

        // With nothing at work every card has the same share.
        let even = OverviewScanLayout.frames(count: 6, featured: nil, in: size, spacing: 16)
        #expect(Set(even.map { ($0.width * 100).rounded() }).count == 1)
        #expect(Set(even.map { ($0.height * 100).rounded() }).count == 1)

        // Five parts, as on a Mac without developer tools: three over two.
        let five = OverviewScanLayout.frames(count: 5, featured: nil, in: size, spacing: 16)
        #expect(five.count { $0.minY == 0 } == 3)
        #expect(abs(five[4].maxX - 1000) < 0.01)
    }

    @Test func theFirstPartStillAtWorkIsTheOneShownAtWork() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let model = AppModel(home: home)
        #expect(model.featuredScan == nil)

        // Every part is scanned side by side. The one shown at work is the first in the sidebar's order.
        model.cleanUp(.system).showDemo("scanning")
        model.apps.showDemo("scanning")
        model.performance.showDemo("scanning")
        #expect(model.featuredScan == .group(.system))
        #expect(model.scanTitle(of: .group(.system)) == "Scanning the system areas")
        #expect(model.scanDetail(of: .group(.system)) == model.cleanUp(.system).scanDetail)
        #expect(model.cleanUp(.system).scanDetail.hasSuffix("areas done"))
        #expect(model.overviewFigure(of: .group(.system)) == OverviewFigure("Scanning", "still looking"))

        // When it is done the next one still at work takes its place, and the card says what was found.
        model.cleanUp(.system).show(findings: [finding(id: "logs", area: .cachesLogs, size: 2_000_000_000)])
        #expect(model.featuredScan == .performance)
        #expect(model.overviewFigure(of: .group(.system)).value == ByteFormat.string(2_000_000_000))
        #expect(model.overviewFigure(of: .group(.system)).caption == "of junk found")
        #expect(model.scanTitle(of: .performance) == "Examining your Mac")
        #expect(model.scanDetail(of: .performance) == model.performance.progress)

        model.performance.showDemo("summary")
        #expect(model.featuredScan == .apps)
        #expect(model.scanTitle(of: .apps) == "Looking at your apps")
        #expect(model.scanDetail(of: .apps) == model.apps.progress.detail)

        model.apps.showDemo("summary")
        #expect(model.featuredScan == nil)
        // A part nobody has scanned says so on its card, as on its tile.
        #expect(model.overviewFigure(of: .protection) == OverviewFigure("Not scanned", "open it to scan on its own"))
    }

    @Test func theAppsScanSaysWhatItIsOn() {
        #expect(AppScanProgress().detail == "Listing the Applications folders")
        #expect(AppScanProgress(done: 3, total: 9, name: "Keynote").detail == "Measuring Keynote and the files it keeps")
        #expect(AppScanProgress(done: 9, total: 9, name: "Keynote", isCheckingUpdates: true).detail == "Asking the update feeds which versions are current")
    }
}
