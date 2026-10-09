//
//  UninstallerPane.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The uninstaller: the installed apps, narrowed by the chosen filter and the search. Ticking an app
/// ticks everything it keeps; opening it shows those files one by one.
struct UninstallerPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var apps = model.apps
        let shown = apps.visibleApps
        VStack(alignment: .leading, spacing: Design.Spacing.large) {
            PaneHeading(title: apps.filter.title, detail: detail(for: apps.filter)) {
                SearchField(text: $apps.search, prompt: "Search apps")
                Spacer(minLength: 0)
                Menu("Select") {
                    Button("All Shown", action: apps.selectAllVisible)
                    Button("None", action: apps.selectNone)
                }
                .fixedSize()
                Picker("Sort by", selection: $apps.sort) {
                    ForEach(AppsModel.Sort.allCases) { sort in
                        Text("By \(sort.title)").tag(sort)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .help("How the apps are ordered")
            }
            if shown.isEmpty {
                ContentUnavailableView {
                    Label(emptyTitle(for: apps), systemImage: "square.grid.2x2")
                } description: {
                    Text(emptyDetail(for: apps))
                }
            } else {
                ScrollView {
                    GlassPanel {
                        LazyVStack(spacing: 0) {
                            ForEach(shown) { app in
                                AppRow(app: app, showsDivider: app.id != shown.first?.id)
                                if apps.isExpanded(app) {
                                    AppFileList(app: app)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func detail(for filter: AppsModel.Filter) -> String {
        switch filter {
        case .all: "Remove whole apps together with the files they keep in your Library."
        case .unused: "Apps you have not opened for 6 months or more."
        case .selected: "The apps and files you have ticked."
        case .source(.appStore): "Apps installed from the App Store. They belong to the system, so Finder moves them and macOS asks for your password."
        case .source(.other): "Apps installed from a download, a disk image or a package."
        case .vendor(let vendor): vendor == .other ? "Apps from every other maker." : "Apps made by \(vendor.title)."
        }
    }

    private func emptyTitle(for apps: AppsModel) -> String {
        if !apps.search.trimmingCharacters(in: .whitespaces).isEmpty { return "No app matches" }
        switch apps.filter {
        case .unused: return "No unused apps"
        case .selected: return "Nothing ticked yet"
        default: return "No apps here"
        }
    }

    private func emptyDetail(for apps: AppsModel) -> String {
        if !apps.search.trimmingCharacters(in: .whitespaces).isEmpty { return "No app in this list has “\(apps.search)” in its name." }
        switch apps.filter {
        case .unused: return "Every app was opened in the last 6 months."
        case .selected: return "Apps and files you tick will be listed here."
        default: return "The Applications folders hold no app of this kind."
        }
    }
}
