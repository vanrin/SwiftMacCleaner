//
//  OverviewScanLayout.swift
//  SwiftMacCleaner
//

import CoreGraphics

/// Where the cards of the overview's scan stand: in two rows, with the row that holds the card at
/// work taller than the other, and that card wider than the ones beside it. When the work moves
/// on, the cards make room for the next.
nonisolated enum OverviewScanLayout {
    /// How many times taller the row at work is than the other, and how many times wider the card
    /// at work is than a card beside it.
    static let rowEmphasis = 2.3
    static let cardEmphasis = 2.8

    /// How many cards stand in a row: all of them in one row up to three, otherwise half in each,
    /// with the first row the longer one when they do not divide.
    static func cardsPerRow(count: Int) -> Int {
        count <= 3 ? max(count, 1) : (count + 1) / 2
    }

    /// The frame of each card, in the order of the parts.
    ///
    /// - Parameter featured: Which card is the one at work, if any is.
    static func frames(count: Int, featured: Int?, in size: CGSize, spacing: Double) -> [CGRect] {
        guard count > 0 else { return [] }
        let perRow = cardsPerRow(count: count)
        let rows = stride(from: 0, to: count, by: perRow).map { Array($0..<min($0 + perRow, count)) }
        let featuredRow = rows.firstIndex { row in featured.map(row.contains) ?? false }
        let heights = lengths(weights: rows.indices.map { $0 == featuredRow ? rowEmphasis : 1 },
                              filling: size.height, spacing: spacing)

        var frames = [CGRect](repeating: .zero, count: count)
        var top = 0.0
        for (row, cards) in rows.enumerated() {
            let widths = lengths(weights: cards.map { $0 == featured ? cardEmphasis : 1 },
                                 filling: size.width, spacing: spacing)
            var left = 0.0
            for (card, width) in zip(cards, widths) {
                frames[card] = CGRect(x: left, y: top, width: width, height: heights[row])
                left += width + spacing
            }
            top += heights[row] + spacing
        }
        return frames
    }

    /// Shares a length out by weight, with the gaps between the shares taken off first.
    private static func lengths(weights: [Double], filling length: Double, spacing: Double) -> [Double] {
        let room = max(length - spacing * Double(weights.count - 1), 0)
        let total = weights.reduce(0, +)
        return weights.map { room * $0 / total }
    }
}
