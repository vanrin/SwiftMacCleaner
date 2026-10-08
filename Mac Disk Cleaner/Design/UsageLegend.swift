//
//  UsageLegend.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// What each colour in a ring or a bar stands for, wrapping onto as many lines as it needs.
struct UsageLegend: View {
    let segments: [UsageSegment]

    var body: some View {
        FlowLayout(spacing: Design.Spacing.small, lineSpacing: Design.Spacing.tight) {
            ForEach(segments) { segment in
                LegendItem(segment: segment)
                    .padding(.trailing, Design.Spacing.small)
            }
        }
    }
}
