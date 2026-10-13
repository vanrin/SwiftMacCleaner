//
//  ReviewFateRow.swift
//  SwiftMacCleaner
//

import SwiftUI

/// A heading on the confirmation over the groups that share a fate: what becomes of them, and how
/// much that is in all.
struct ReviewFateRow: View {
    let fate: CleanFate
    /// What the groups under the heading add up to, less the ones that wait.
    let size: Int64
    var showsDivider = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Design.Spacing.medium) {
            VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
                Text(fate.title)
                    .font(.callout)
                    .bold()
                    .textCase(.uppercase)
                Text(fate.detail)
                    .font(.callout)
            }
            Spacer(minLength: Design.Spacing.medium)
            // Tasks free nothing that can be measured, so their heading carries no figure.
            if size > 0 {
                SizeLabel(bytes: size)
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, Design.Spacing.large)
        .padding(.top, Design.Spacing.large)
        .padding(.bottom, Design.Spacing.tight)
        .overlay(alignment: .top) {
            Divider()
                .opacity(showsDivider ? 1 : 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
