//
//  AppsPaneHeading.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The top of one part of the manager: what the list under it shows, and the controls that shape that list.
struct AppsPaneHeading<Controls: View>: View {
    let title: String
    let detail: String
    @ContentBuilder var controls: Controls

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.medium) {
            VStack(alignment: .leading, spacing: Design.Spacing.tight) {
                Text(title)
                    .font(Design.Typeface.tileTitle)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Design.Spacing.medium) {
                controls
            }
        }
    }
}
