//
//  AreaPickerPopover.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// Every area the scan can look at, each to tick or untick, and under them what no scan ever touches.
struct AreaPickerPopover: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(
                title: "What the scan looks at",
                detail: "Untick anything you want left alone. Tools that are not installed are skipped. Scanning only measures."
            )
            .padding(Design.Spacing.large)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Area.allCases) { area in
                        AreaToggleRow(area: area)
                    }
                    NeverTouchedPanel()
                        .padding(Design.Spacing.large)
                }
                .padding(.vertical, Design.Spacing.small)
            }
        }
        .frame(width: Design.Size.popoverWidth, height: Design.Size.popoverHeight)
    }
}
