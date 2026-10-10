//
//  DuplicateGroupCard.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One group of identical files: what they are, what keeping one of them gives back, and every copy
/// with a tick box of its own. The box on the heading ticks every copy but the one most worth keeping.
struct DuplicateGroupCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let group: DuplicateGroup

    var body: some View {
        let duplicates = model.duplicates
        GlassPanel {
            HStack(spacing: Design.Spacing.medium) {
                Toggle(sources: duplicates.bindings(forExtrasOf: group), isOn: \.self) {
                    HStack(spacing: Design.Spacing.medium) {
                        FeatureIcon(Image(systemName: group.kind.symbol), theme: theme)
                        TitledDetail(title: group.name, detail: detail)
                    }
                }
                .toggleStyle(.check)
                .accessibilityLabel("Extra copies of \(group.name)")
                Spacer(minLength: Design.Spacing.medium)
                VStack(alignment: .trailing, spacing: Design.Spacing.tight / 2) {
                    SizeLabel(bytes: group.reclaimable)
                    Text("to get back")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, Design.Spacing.large)
            .padding(.vertical, Design.Spacing.medium)

            ForEach(group.files) { file in
                VStack(spacing: 0) {
                    Divider()
                    DuplicateFileRow(file: file, group: group)
                }
            }
        }
    }

    /// "3 copies · 18 MB each".
    private var detail: String {
        "\(group.files.count) copies · \(ByteFormat.string(group.size)) each"
    }
}
