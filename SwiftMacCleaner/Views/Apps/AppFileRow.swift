//
//  AppFileRow.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One file or folder an app keeps: its name, where it is, and how big it is.
struct AppFileRow: View {
    @Environment(AppModel.self) private var model
    let file: AppFile

    var body: some View {
        let apps = model.apps
        HStack(spacing: Design.Spacing.medium) {
            Toggle(isOn: apps.binding(for: file)) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(file.url.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(apps.displayPath(file.url.deletingLastPathComponent()))
                        .font(Design.Typeface.code)
                        .foregroundStyle(.quiet)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .toggleStyle(.check)
            if file.isSystemWide {
                Badge(text: "Asks for your password", style: .password)
                    .help("Belongs to the system. It is stopped and moved with your password, and Put Back cannot return it.")
            }
            Spacer(minLength: Design.Spacing.medium)
            SizeLabel(bytes: file.size, isEmphasized: false, unknown: file.sizeUnknown)
            Button("Show \(file.url.lastPathComponent) in Finder", systemImage: "magnifyingglass", action: showInFinder)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Show in Finder")
        }
        .padding(.leading, Design.Spacing.section)
        .padding(.vertical, Design.Spacing.tight)
        .contextMenu {
            Button("Show in Finder", action: showInFinder)
            Button("Copy Path", action: copyPath)
        }
    }

    private func showInFinder() {
        model.showInFinder(file.url)
    }

    private func copyPath() {
        model.copyPath(file.url)
    }
}
