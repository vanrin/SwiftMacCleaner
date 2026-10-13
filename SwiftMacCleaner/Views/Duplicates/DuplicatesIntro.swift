//
//  DuplicatesIntro.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Duplicates before a scan: what it does, and where it should look.
struct DuplicatesIntro: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var duplicates = model.duplicates
        IntroLayout {
            ModuleHero(.duplicates)
        } details: {
            IntroHeading(
                title: "Duplicates",
                detail: "Find files that are the same to the last byte, wherever they are and whatever they are called, and keep one of each."
            )
            VStack(alignment: .leading, spacing: Design.Spacing.large) {
                FeatureBullet(glyph: Image(systemName: "equal.circle.fill"), text: "Compared by what is in them")
                FeatureBullet(glyph: Image(systemName: "checkmark.shield.fill"), text: "One copy always stays")
                FeatureBullet(glyph: Image(systemName: "internaldrive.fill"), text: "Counts only space you really get back")
            }
            VStack(alignment: .leading, spacing: Design.Spacing.small) {
                HStack(spacing: Design.Spacing.medium) {
                    Picker("Where to look", selection: $duplicates.scope) {
                        ForEach(DuplicatesModel.Scope.allCases) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .controlSize(.large)
                    if duplicates.scope == .folder {
                        Button(duplicates.folder == nil ? "Choose…" : "Change…", action: chooseFolder)
                            .buttonStyle(.pill)
                    }
                }
                Text(explanation(duplicates))
                    .foregroundStyle(.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                if let note = duplicates.folderNote {
                    Label(note, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(Design.Signal.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .orbAction {
            Button("Scan", action: duplicates.start)
                .buttonStyle(.orb)
                .keyboardShortcut(.defaultAction)
                .disabled(!duplicates.canScan)
                .accessibilityLabel("Scan for duplicates")
                .help(duplicates.canScan ? "Look for identical files. Only reads, and can be stopped." : "Choose a folder first")
        }
    }

    private func explanation(_ duplicates: DuplicatesModel) -> String {
        let leftOut = "Your Library, apps, projects, caches and anything hidden are left out, and nothing kept only in iCloud is downloaded."
        switch duplicates.scope {
        case .home:
            return "Your own files in \(duplicates.displayPath(duplicates.home)): Desktop, Documents, Downloads, Pictures and the rest. \(leftOut)"
        case .folder:
            guard let folder = duplicates.folder else { return "Choose a folder to look through. \(leftOut)" }
            return "Everything in \(duplicates.displayPath(folder)). \(leftOut)"
        }
    }

    private func chooseFolder() {
        model.duplicates.showingFolderPicker = true
    }
}
