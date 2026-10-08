//
//  AppsColumn.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The column beside the manager's list: its three parts, and under them the filters of the uninstaller.
struct AppsColumn: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let apps = model.apps
        ScrollView {
            VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
                ForEach(AppsModel.Section.allCases) { section in
                    AppsColumnRow(title: section.title, value: value(for: section, in: apps), isSelected: apps.section == section,
                                  isProminent: true) {
                        apps.section = section
                    }
                }
                if apps.section == .uninstaller {
                    Divider()
                        .padding(.vertical, Design.Spacing.small)
                    ForEach([AppsModel.Filter.all, .unused, .selected], id: \.self) { filter in
                        filterRow(filter, in: apps)
                    }
                    if !apps.sources.isEmpty {
                        heading("Stores")
                        ForEach(apps.sources, id: \.self) { source in
                            filterRow(.source(source), in: apps)
                        }
                    }
                    if !apps.vendors.isEmpty {
                        heading("Makers")
                        ForEach(apps.vendors, id: \.self) { vendor in
                            filterRow(.vendor(vendor), in: apps)
                        }
                    }
                }
            }
        }
        .scrollIndicators(.never)
    }

    private func filterRow(_ filter: AppsModel.Filter, in apps: AppsModel) -> some View {
        AppsColumnRow(title: filter.title, value: apps.count(for: filter).formatted(), isSelected: apps.filter == filter) {
            apps.filter = filter
        }
    }

    private func heading(_ title: String) -> some View {
        Text(title)
            .font(.callout)
            .bold()
            .foregroundStyle(.secondary)
            .padding(.horizontal, Design.Spacing.medium)
            .padding(.top, Design.Spacing.medium)
            .padding(.bottom, Design.Spacing.tight)
            .accessibilityAddTraits(.isHeader)
    }

    /// What stands at the end of a part's row: how much is in it.
    private func value(for section: AppsModel.Section, in apps: AppsModel) -> String {
        switch section {
        case .uninstaller: apps.apps.count.formatted()
        case .updater: apps.updates.count.formatted()
        case .leftovers: ByteFormat.string(apps.installerSize + apps.leftoverFileSize)
        }
    }
}
