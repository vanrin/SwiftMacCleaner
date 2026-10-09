//
//  SidebarHint.swift
//  SwiftMacCleaner
//

import SwiftUI

/// A rail entry's request for a label beside it: its name, what its scan found, and where it sits.
nonisolated struct SidebarHint: Equatable {
    let title: String
    var detail: String?
    let bounds: Anchor<CGRect>
}

extension View {
    /// Asks for a label with this entry's name beside it. The rail shows only glyphs, so the entry
    /// under the pointer says what it is.
    func sidebarHint(_ title: String, detail: String? = nil, isShown: Bool) -> some View {
        anchorPreference(key: SidebarHintKey.self, value: .bounds) { bounds in
            isShown ? SidebarHint(title: title, detail: detail, bounds: bounds) : nil
        }
    }
}
