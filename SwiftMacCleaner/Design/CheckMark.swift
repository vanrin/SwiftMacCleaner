//
//  CheckMark.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The round tick box itself: empty, ticked, or a dash when only some of what it covers is ticked.
struct CheckMark: View {
    var isOn: Bool
    var isMixed = false

    var body: some View {
        Image(systemName: symbol)
            .font(.title2)
            .symbolRenderingMode(.palette)
            // A white tick on a graphite disc; an empty box is a ring in the quieter ink.
            .foregroundStyle(isOn || isMixed ? .white : Design.Ink.secondary, Design.Ink.primary)
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
