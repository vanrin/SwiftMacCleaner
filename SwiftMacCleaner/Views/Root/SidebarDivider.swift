//
//  SidebarDivider.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The faint line between the sidebar and the screen beside it. It fades out towards both ends.
struct SidebarDivider: View {
    var body: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, Design.Surface.track, Design.Surface.track, .clear],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: Design.Spacing.hairline)
            .padding(.vertical, Design.Spacing.section)
            .accessibilityHidden(true)
    }
}
