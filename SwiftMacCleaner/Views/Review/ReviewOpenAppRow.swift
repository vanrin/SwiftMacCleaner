//
//  ReviewOpenAppRow.swift
//  SwiftMacCleaner
//

import AppKit
import SwiftUI

/// An open app on the confirmation: how much waits for it, and a button that asks it to quit.
struct ReviewOpenAppRow: View {
    let entry: BlockingApp
    var showsDivider = true
    let quit: () -> Void

    var body: some View {
        HStack(spacing: Design.Spacing.medium) {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: entry.app.bundleID) {
                AppIconView(url: url)
            }
            VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
                Text(entry.app.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(ByteFormat.string(entry.size)) waits for it")
                    .font(.callout)
                    .foregroundStyle(.quiet)
                    .lineLimit(1)
            }
            Spacer(minLength: Design.Spacing.medium)
            Button("Quit", action: quit)
                .buttonStyle(.pill)
                .accessibilityLabel("Quit \(entry.app.name)")
                .help("Asks \(entry.app.name) to quit, as its own Quit command would. It can still ask about unsaved work")
        }
        .padding(.horizontal, Design.Spacing.large)
        .padding(.vertical, Design.Spacing.medium)
        .overlay(alignment: .top) {
            Divider()
                .opacity(showsDivider ? 1 : 0)
        }
    }
}
