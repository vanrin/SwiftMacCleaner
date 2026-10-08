//
//  PutBackMessage.swift
//  SwiftMacCleaner
//

import SwiftUI

/// A one-line confirmation after Put Back.
struct PutBackMessage: View {
    let text: String

    var body: some View {
        GlassPanel {
            Label {
                Text(text)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }
            .padding(Design.Spacing.large)
        }
    }
}
