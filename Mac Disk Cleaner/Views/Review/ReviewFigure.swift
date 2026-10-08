//
//  ReviewFigure.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// A figure on the confirmation with a caption over it, such as "Free after".
struct ReviewFigure: View {
    let caption: String
    let value: String
    var isEmphasized = false
    var alignment = HorizontalAlignment.leading

    var body: some View {
        VStack(alignment: alignment, spacing: Design.Spacing.tight / 2) {
            Text(caption)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .monospacedDigit()
                .bold(isEmphasized)
        }
        .accessibilityElement(children: .combine)
    }
}
