//
//  PresetControl.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Smart, Everything, Nothing: the three ways to set every tick of a list at once, side by side. The
/// one the ticks amount to is lit; none is, once rows have been ticked by hand.
struct PresetControl: View {
    @Environment(\.theme) private var theme

    let preset: SelectionPreset?
    let select: (SelectionPreset) -> Void

    var body: some View {
        HStack(spacing: Design.Spacing.medium) {
            Text("Select")
                .foregroundStyle(.secondary)
            HStack(spacing: Design.Spacing.tight / 2) {
                ForEach(SelectionPreset.allCases) { choice in
                    let isChosen = choice == preset
                    Button(choice.title) { select(choice) }
                        .buttonStyle(.plain)
                        .bold()
                        .padding(.horizontal, Design.Spacing.medium)
                        .padding(.vertical, Design.Spacing.small)
                        .foregroundStyle(isChosen ? AnyShapeStyle(theme.deep) : AnyShapeStyle(.white))
                        .background(isChosen ? AnyShapeStyle(.white) : AnyShapeStyle(.clear),
                                    in: .rect(cornerRadius: Design.Radius.control - Design.Spacing.tight))
                        .contentShape(.rect(cornerRadius: Design.Radius.control - Design.Spacing.tight))
                        .accessibilityAddTraits(isChosen ? .isSelected : [])
                        .help(help(for: choice))
                }
            }
            .padding(Design.Spacing.tight / 2 + 1)
            .background(Design.Surface.well, in: .rect(cornerRadius: Design.Radius.control))
            .animation(Design.Motion.press, value: preset)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Select")
    }

    private func help(for choice: SelectionPreset) -> String {
        switch choice {
        case .smart: "Tick what the scan ticks by itself. Settings says what that is"
        case .everything: "Tick every row here, whatever removing it costs"
        case .nothing: "Untick every row here"
        }
    }
}
