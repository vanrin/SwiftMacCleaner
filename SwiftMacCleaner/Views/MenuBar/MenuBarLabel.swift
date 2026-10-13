//
//  MenuBarLabel.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The item in the menu bar: the app's glyph, and beside it the readings the user asked to see there.
struct MenuBarLabel: View {
    let vitals: VitalsModel

    var body: some View {
        Image(.menuBarGlyph)
            .accessibilityLabel("SwiftMacCleaner")
        if let readings = vitals.iconReadings {
            Text(readings)
                .monospacedDigit()
        }
    }
}
