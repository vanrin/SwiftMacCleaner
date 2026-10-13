//
//  SelectionMenu.swift
//  SwiftMacCleaner
//

import SwiftUI

/// "Select: Smart", opening onto the three ways to set every tick at once. For the screens that sum
/// a whole clean-up up, where there is no room for the three side by side.
struct SelectionMenu: View {
    let preset: SelectionPreset?
    let select: (SelectionPreset) -> Void

    var body: some View {
        Menu("Select: \(preset?.title ?? "Custom")") {
            ForEach(SelectionPreset.allCases) { choice in
                Toggle(choice.title, isOn: isOn(choice))
            }
        }
        .fixedSize()
        .help("Smart ticks what the scan ticks by itself. Everything and Nothing set every row at once")
    }

    /// A tick beside the preset in force. Choosing one sets it; choosing the one in force changes nothing.
    private func isOn(_ choice: SelectionPreset) -> Binding<Bool> {
        Binding(get: { preset == choice }, set: { _ in select(choice) })
    }
}
