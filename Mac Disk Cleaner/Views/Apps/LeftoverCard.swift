//
//  LeftoverCard.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// One group of leftovers: why they can go, and every item in it with a tick box.
struct LeftoverCard: View {
    @Environment(AppModel.self) private var model
    let finding: Finding

    var body: some View {
        let apps = model.apps
        GlassPanel {
            VStack(alignment: .leading, spacing: Design.Spacing.medium) {
                HStack(spacing: Design.Spacing.medium) {
                    Toggle(sources: apps.bindings(for: finding), isOn: \.self) {
                        Text(title)
                            .font(Design.Typeface.tileTitle)
                            .lineLimit(1)
                    }
                    .toggleStyle(.check)
                    Spacer(minLength: Design.Spacing.medium)
                    SizeLabel(bytes: finding.size)
                }
                Text(finding.explanation)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Design.Spacing.large)

            ForEach(finding.items) { item in
                VStack(spacing: 0) {
                    Divider()
                    LeftoverRow(item: item)
                }
            }
        }
    }

    /// A short name for the group, which the scanner's own title is too long to be on this screen.
    private var title: String {
        switch finding.id {
        case AppsModel.installersFindingID: "Installers"
        case AppsModel.leftoverFilesFindingID: "Leftover Files"
        default: finding.title
        }
    }
}
