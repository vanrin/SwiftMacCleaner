//
//  TitleBarLabelStyle.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// An icon and its title for a button in the title bar, with room on both sides so the text does not sit
/// against the edge of the glass.
struct TitleBarLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Design.Spacing.small) {
            configuration.icon
            configuration.title
        }
        .padding(.horizontal, Design.Spacing.small)
    }
}

extension LabelStyle where Self == TitleBarLabelStyle {
    static var titleBar: TitleBarLabelStyle { TitleBarLabelStyle() }
}
