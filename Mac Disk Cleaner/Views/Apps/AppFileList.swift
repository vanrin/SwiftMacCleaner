//
//  AppFileList.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// Everything one app keeps, grouped by what it is for, each group and each file with a tick box of its own.
struct AppFileList: View {
    @Environment(AppModel.self) private var model
    let app: InstalledApp

    var body: some View {
        let apps = model.apps
        VStack(spacing: 0) {
            ForEach(app.kinds, id: \.self) { kind in
                let files = app.files(of: kind)
                HStack(spacing: Design.Spacing.medium) {
                    Toggle(sources: apps.bindings(for: files), isOn: \.self) {
                        HStack(spacing: Design.Spacing.small) {
                            Image(systemName: kind.symbol)
                                .foregroundStyle(.secondary)
                                .frame(width: Design.Size.sidebarGlyph)
                                .accessibilityHidden(true)
                            Text(kind.title)
                                .font(.headline)
                        }
                    }
                    .toggleStyle(.check)
                    Spacer(minLength: Design.Spacing.medium)
                    SizeLabel(bytes: files.reduce(0) { $0 + $1.size }, isEmphasized: false)
                }
                .padding(.vertical, Design.Spacing.small)
                ForEach(files) { file in
                    AppFileRow(file: file)
                }
            }
        }
        .padding(.leading, Design.Spacing.section + Design.Spacing.large)
        .padding(.trailing, Design.Spacing.large)
        .padding(.bottom, Design.Spacing.small)
        .background(Design.Surface.hover)
    }
}
