//
//  NeverTouchedPanel.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What no scan ever offers, whatever is ticked.
struct NeverTouchedPanel: View {
    private static let neverTouched = [
        "Your source files", "Git repositories", "iCloud Drive and cloud folders", "Files not downloaded from iCloud",
        "Photos, Mail, Messages libraries", "Keychains and credentials", "Docker volumes",
        "Other disks and network volumes", "The current Xcode and your default toolchains",
        "Anything changed after the scan", "Your Never Suggest list",
    ]

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: Design.Spacing.medium) {
                Label {
                    Text("Never touched, whatever you tick")
                        .font(.headline)
                } icon: {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.tint)
                }
                FlowLayout(spacing: Design.Spacing.small) {
                    ForEach(Self.neverTouched, id: \.self) { chip in
                        Text(chip)
                            .font(.callout)
                            .padding(.horizontal, Design.Spacing.medium)
                            .padding(.vertical, Design.Spacing.tight)
                            .background(Design.Surface.well, in: .capsule)
                    }
                }
            }
            .padding(Design.Spacing.large)
        }
    }
}
