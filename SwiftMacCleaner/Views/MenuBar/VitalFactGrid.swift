//
//  VitalFactGrid.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The figures of a reading's details, two tiles to a row.
struct VitalFactGrid: View {
    let facts: [VitalFact]

    var body: some View {
        Grid(horizontalSpacing: Design.Spacing.small, verticalSpacing: Design.Spacing.small) {
            ForEach(Array(stride(from: 0, to: facts.count, by: Self.columns)), id: \.self) { first in
                GridRow {
                    ForEach(facts[first..<min(first + Self.columns, facts.count)]) { fact in
                        VitalFactTile(fact: fact)
                    }
                }
            }
        }
        // The tiles fill their row, so the grid is held to the height its tallest tiles ask for.
        .fixedSize(horizontal: false, vertical: true)
    }

    private static let columns = 2
}
