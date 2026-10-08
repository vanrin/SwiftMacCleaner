//
//  SizeLabel.swift
//  SwiftMacCleaner
//

import SwiftUI

/// A size in figures of equal width, so columns of sizes line up.
struct SizeLabel: View {
    let bytes: Int64
    /// Bold by default. Rows that were skipped or are only shown say their size more quietly.
    var isEmphasized = true
    /// macOS could not say how big this is, so the row says so instead of showing a number.
    var unknown = false

    var body: some View {
        Text(unknown ? "size unknown" : ByteFormat.string(bytes))
            .font(Design.Typeface.tileBody)
            .monospacedDigit()
            .bold(isEmphasized && !unknown)
            .foregroundStyle(unknown ? AnyShapeStyle(.secondary) : AnyShapeStyle(.foreground))
            .lineLimit(1)
    }
}
