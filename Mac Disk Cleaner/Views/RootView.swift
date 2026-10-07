//
//  RootView.swift
//  Mac Disk Cleaner
//

import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            detail
                .toolbar { toolbar }
        }
        .sheet(isPresented: $model.showingReview) {
            ReviewSheet()
        }
        .frame(minWidth: 880, minHeight: 600)
    }

    @ViewBuilder
    private var detail: some View {
        if model.sidebarSelection == .space {
            // Largest Folders stands apart from the clean-up flow and is reachable in any phase.
            SpaceView()
        } else {
            switch model.phase {
            case .home:
                HomeView()
            case .scanning:
                ScanningView()
            case .results:
                if case .area(let area) = model.sidebarSelection {
                    AreaDetailView(area: area)
                } else {
                    OverviewView()
                }
            case .cleaning:
                CleaningView()
            case .done:
                DoneView()
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        // Largest Folders brings its own toolbar, so these belong to the clean-up flow only.
        let inCleanUp = model.sidebarSelection != .space
        if inCleanUp, model.phase == .scanning {
            ToolbarItem(placement: .primaryAction) {
                Button("Stop", systemImage: "stop.fill") { model.stopScan() }
                    .help("Stop scanning and show what was found so far")
            }
        }
        if inCleanUp, model.phase == .results || model.phase == .done {
            ToolbarItem(placement: .primaryAction) {
                Button("Rescan", systemImage: "arrow.clockwise") { model.startScan() }
                    .help("Scan again")
            }
        }
    }
}

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List(selection: selection) {
            Label("Overview", systemImage: "chart.pie")
                .badge(overviewBadge)
                .tag(SidebarItem.overview)
            Section("Developer") {
                ForEach(Area.allCases.filter(\.isDeveloper)) { row(for: $0) }
            }
            Section("System") {
                ForEach(Area.allCases.filter { !$0.isDeveloper }) { row(for: $0) }
            }
            Section("Explore") {
                Label("Largest Folders", systemImage: "chart.bar.doc.horizontal")
                    .tag(SidebarItem.space)
            }
        }
        .safeAreaInset(edge: .bottom, alignment: .leading) {
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private var selection: Binding<SidebarItem?> {
        Binding(
            get: { model.sidebarSelection },
            set: { if let item = $0 { model.select(item) } }
        )
    }

    private func row(for area: Area) -> some View {
        Label(area.title, systemImage: area.symbol)
            .badge(badge(for: area))
            .foregroundStyle(model.phase == .results || model.phase == .done ? .primary : .secondary)
            .tag(SidebarItem.area(area))
    }

    private var overviewBadge: Text? {
        switch model.phase {
        case .scanning, .results, .done:
            model.foundSize > 0 ? Text(ByteFormat.string(model.foundSize)) : nil
        case .home, .cleaning:
            nil
        }
    }

    private func badge(for area: Area) -> Text? {
        switch model.areaState(for: area) {
        case .idle: nil
        case .queued: Text("Queued")
        case .scanning: Text("Scanning")
        case .skipped: Text("Skipped")
        case .finished:
            model.foundSize(in: area) > 0 ? Text(ByteFormat.string(model.foundSize(in: area))) : Text("Clean")
        }
    }
}
