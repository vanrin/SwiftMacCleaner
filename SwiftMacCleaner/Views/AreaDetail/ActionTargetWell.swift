//
//  ActionTargetWell.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What cleaning a finding does, and to which path or with which command, set in a recessed strip.
struct ActionTargetWell: View {
    let verb: String
    let target: String

    var body: some View {
        HStack(spacing: Design.Spacing.small) {
            Text(verb)
                .font(.callout)
                .bold()
                .foregroundStyle(.secondary)
            Text(target)
                .font(Design.Typeface.code)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .padding(.horizontal, Design.Spacing.medium)
        .padding(.vertical, Design.Spacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.Surface.well, in: .rect(cornerRadius: Design.Radius.control))
    }
}
