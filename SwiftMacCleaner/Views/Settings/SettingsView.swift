//
//  SettingsView.swift
//  SwiftMacCleaner
//

import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { GeneralSettings() }
            Tab("Project Folders", systemImage: "folder") { ProjectFolderSettings() }
            Tab("Never Suggest", systemImage: "eye.slash") { NeverSuggestSettings() }
            Tab("Advanced", systemImage: "slider.horizontal.3") { AdvancedSettings() }
        }
        .frame(width: 560)
    }
}

private struct GeneralSettings: View {
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
                Picker("Offer large Downloads after", selection: $settings.largeFileDays) {
                    ForEach(AppSettings.largeFileChoices, id: \.self) { days in
                        Text(days == 365 ? "1 year untouched" : "\(days) days untouched").tag(days)
                    }
                }
            } footer: {
                Text("Files of 100 MB and up in Downloads are offered once they have sat untouched for this long.")
            }
            Section {
                LabeledContent("Recent builds") {
                    Text("DerivedData for projects built in the last 7 days is always kept.")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Toggle("Show disk space in the menu bar", isOn: $settings.showsMenuBarItem)
                Toggle("Check once a week", isOn: $settings.weeklyCheck)
            } footer: {
                Text("The weekly check scans on its own while the app is open and idle, then tells you what it found. It never removes anything.")
            }
            Section {
                Toggle("Look for app updates", isOn: $settings.checksAppUpdates)
            } footer: {
                Text("When Applications scans, it asks the App Store and each app's own update feed which version is current. Only app identifiers and your region are sent. Nothing is installed for you.")
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ProjectFolderSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        Form {
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

private struct NeverSuggestSettings: View {
    @Environment(AppModel.self) private var model

    private static let builtInRules = [
        "Never offer anything from a project in iCloud Drive",
        "Never offer Docker volumes",
        "Never offer the selected Xcode or your default toolchains",
    ]

    var body: some View {
        let settings = model.settings
        Form {
            Section {
                if settings.neverSuggest.isEmpty {
                    Text("Nothing yet. Choose Never Suggest This from any row's menu to add an item.")
                        .foregroundStyle(.secondary)
                }
                ForEach(settings.neverSuggest) { entry in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.title)
                                .fontWeight(.medium)
                            Text(tilde(entry.path))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Text("Added \(entry.added.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Remove") { settings.removeNeverSuggest(entry) }
                    }
                }
            } header: {
                Text("Never Suggest")
            } footer: {
                Text("Anything here is never offered, in any area. It still shows under Protected on the Overview with its size, so you remember it exists. Add items from the row menu on any finding.")
            }
            Section {
                ForEach(Self.builtInRules, id: \.self) { rule in
                    Toggle(rule, isOn: .constant(true))
                        .disabled(true)
                }
            } header: {
                Text("Built-in rules")
            } footer: {
                Text("Built-in rules cannot be switched off. They are listed so you know what the scan skips.")
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func tilde(_ path: String) -> String {
        let home = model.home.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}

private struct AdvancedSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                Toggle("Offer older Xcode versions in Applications", isOn: $settings.offersOldXcodes)
                Toggle("Offer local snapshots (asks for your password)", isOn: $settings.offersSnapshots)
            } footer: {
                Text("The selected Xcode is never offered. Removing local snapshots is the only step that needs a password; everything else runs as you.")
            }
            Section {
                LabeledContent("Logs") {
                    Button("Open Log Folder") {
                        let folder = model.home.appending(path: "Library/Logs").appending(path: CleanLog.folderName)
                        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(folder)
                    }
                }
            } footer: {
                Text("Every clean writes a log with each path it removed, skipped or could not touch.")
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }
}
