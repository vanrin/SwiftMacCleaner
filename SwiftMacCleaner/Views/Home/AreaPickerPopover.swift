//
//  AreaPickerPopover.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Every area the scan can look at, each to tick or untick, and under them what no scan ever touches.
struct AreaPickerPopover: View {
    @Environment(AppModel.self) private var model
    /// The areas on offer: every area of the clean-up, or one clean-up's.
    var areas = Area.cleanUp

    var body: some View {
        let stack = model.stack
        // Developer areas whose tools are not on this Mac go last, unticked until asked for.
        let missing = areas.filter { !stack.applies($0) }
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(
                title: "What the scan looks at",
                detail: "Untick anything you want left alone. Developer areas follow the tools found on this Mac. Scanning only measures."
            )
            .padding(Design.Spacing.large)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(areas.filter(stack.applies)) { area in
                        AreaToggleRow(area: area)
                    }
                    if !missing.isEmpty {
                        SectionHeading(
                            title: "Not found on this Mac",
                            detail: "Nothing from these tools turned up. Tick one to scan it anyway."
                        )
                        .padding(.horizontal, Design.Spacing.large)
                        .padding(.top, Design.Spacing.large)
                        .padding(.bottom, Design.Spacing.small)
                        ForEach(missing) { area in
                            AreaToggleRow(area: area)
                        }
                    }
                    NeverTouchedPanel()
                        .padding(Design.Spacing.large)
                }
                .padding(.vertical, Design.Spacing.small)
            }
        }
        .frame(width: Design.Size.popoverWidth, height: Design.Size.popoverHeight)
        .task { model.refreshStack() }
    }
}
