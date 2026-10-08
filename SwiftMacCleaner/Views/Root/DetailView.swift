//
//  DetailView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The right-hand side of the window: the screen for where the user is in the clean-up, or Largest Folders.
struct DetailView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let inCleanUp = model.sidebarSelection != .space && model.sidebarSelection != .apps
        Group {
            if model.sidebarSelection == .space {
                // Largest Folders stands apart from the clean-up flow and is reachable in any phase.
                SpaceView()
            } else if model.sidebarSelection == .apps {
                // So does Applications, which has a scan and a removal of its own.
                AppsView()
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
        .navigationTitle(title ?? "SwiftMacCleaner")
        .toolbar {
            // Pushes what follows to the right-hand end of the title bar.
            ToolbarSpacer(.flexible)
            if let title {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                // A title is not a control, so it gets no glass behind it.
                .sharedBackgroundVisibility(.hidden)
            }
            if inCleanUp, model.phase == .results, model.sidebarSelection != .overview {
                ToolbarItem(placement: .navigation) {
                    Button("Overview", systemImage: "chevron.left", action: showOverview)
                        .labelStyle(.titleBar)
                        .help("Back to everything the scan found")
                }
            }
            if model.phase == .home || !inCleanUp {
                // The result of an uninstall carries the offer to put things back itself.
                NoticeToolbar(model: model, showsPutBack: inCleanUp || (model.sidebarSelection == .apps && model.apps.phase != .done))
            }
            if inCleanUp, model.phase == .results || model.phase == .done {
                ToolbarItem {
                    Button("Rescan", systemImage: "arrow.clockwise", action: model.startScan)
                        .labelStyle(.titleBar)
                        .help("Scan again")
                }
            }
        }
    }

    /// The small title in the middle of the title bar. The opening screens carry their own large one instead.
    private var title: String? {
        if model.sidebarSelection == .space {
            return model.space.phase == .idle ? nil : "Largest Folders"
        }
        if model.sidebarSelection == .apps {
            return model.apps.phase == .idle ? nil : "Applications"
        }
        switch model.phase {
        case .home: return nil
        case .scanning: return "Scanning"
        case .cleaning: return "Cleaning"
        case .done: return "Overview"
        case .results:
            if case .area(let area) = model.sidebarSelection { return area.title }
            return "Overview"
        }
    }

    private func showOverview() {
        model.select(.overview)
    }
}
