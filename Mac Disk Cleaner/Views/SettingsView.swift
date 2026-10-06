//
//  SettingsView.swift
//  Mac Disk Cleaner
//

import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                Picker("Offer build folders after", selection: $settings.staleDays) {
                    ForEach(AppSettings.staleChoices, id: \.self) { days in
                        Text(days == 180 ? "6 months untouched" : "\(days) days untouched").tag(days)
                    }
                }
            } footer: {
                Text("A project counts as stale when none of its files have changed for this long.")
            }

            Section {
                if settings.projectRoots.isEmpty {
                    Text("No folders yet. Add the folder that holds your projects.")
                        .foregroundStyle(.secondary)
                }
                ForEach(settings.projectRoots, id: \.self) { path in
                    HStack {
                        Text(tilde(path))
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Remove") {
                            settings.projectRoots.removeAll { $0 == path }
                        }
                    }
                }
                Button("Add Folder…") { addFolders(to: settings) }
            } header: {
                Text("Project folders")
            } footer: {
                Text("Only dependency and build folders inside these are ever offered. Source files are never touched.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func tilde(_ path: String) -> String {
        let home = model.home.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private func addFolders(to settings: AppSettings) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls where !settings.projectRoots.contains(url.path) {
            settings.projectRoots.append(url.path)
        }
    }
}
