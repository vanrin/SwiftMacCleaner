//
//  SidebarEntryStyle.swift
//  SwiftMacCleaner
//

import SwiftUI

/// A sidebar entry as a button. It draws nothing of its own: the label is the whole entry, and is
/// told when it is held down, so its icon can sink.
struct SidebarEntryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.isHeldDown, configuration.isPressed)
    }
}

extension ButtonStyle where Self == SidebarEntryStyle {
    static var sidebarEntry: SidebarEntryStyle { SidebarEntryStyle() }
}

extension EnvironmentValues {
    /// The button a view is the label of is being pressed.
    @Entry var isHeldDown = false
}
