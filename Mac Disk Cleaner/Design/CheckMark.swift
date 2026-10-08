//
//  CheckMark.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// The round tick box itself: empty, ticked, or a dash when only some of what it covers is ticked.
struct CheckMark: View {
    @Environment(\.theme) private var theme
    var isOn: Bool
    var isMixed = false

    var body: some View {
        Image(systemName: symbol)
            .font(.title2)
            .symbolRenderingMode(.palette)
            .foregroundStyle(isOn || isMixed ? AnyShapeStyle(theme.deep) : AnyShapeStyle(.secondary), .white)
            .contentTransition(.symbolEffect(.replace))
            .accessibilityHidden(true)
    }

    private var symbol: String {
        if isMixed {
            "minus.circle.fill"
        } else if isOn {
            "checkmark.circle.fill"
        } else {
            "circle"
        }
    }
}
