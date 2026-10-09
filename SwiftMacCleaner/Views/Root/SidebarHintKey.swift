//
//  SidebarHintKey.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Carries the label a rail entry asks for up to the window, which has the room to draw it.
nonisolated struct SidebarHintKey: PreferenceKey {
    static var defaultValue: SidebarHint? { nil }

    static func reduce(value: inout SidebarHint?, nextValue: () -> SidebarHint?) {
        value = value ?? nextValue()
    }
}
