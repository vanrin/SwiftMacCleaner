//
//  DetailView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The right-hand side of the window: the overview, or one of the parts it runs. Each clean-up's
/// screens read their clean-up from the environment, so the same screens serve every group.
struct DetailView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let item = model.sidebarSelection
        Group {
            switch item {
            case .overview:
                OverviewView()
            case .group(let group):
                CleanUpView()
                    .environment(model.cleanUp(group))
            case .space:
                // Largest Folders stands apart: it measures rather than finds, and is reachable in any phase.
                SpaceView()
            case .duplicates:
                DuplicatesView()
            case .apps:
                AppsView()
            case .performance:
                PerformanceView()
            case .protection:
                ProtectionView()
            case .activity:
                ActivityView()
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
                        .foregroundStyle(.quiet)
                }
                // A title is not a control, so it gets no glass behind it.
                .sharedBackgroundVisibility(.hidden)
            }
            // The result of a clean carries the offer to put things back itself.
            NoticeToolbar(model: model, showsPutBack: showsPutBack)
        }
    }

    private var showsPutBack: Bool {
        switch model.sidebarSelection {
        case .overview: model.overviewPhase != .done
        case .group(let group): model.cleanUp(group).phase != .done
        case .apps: model.apps.phase != .done
        case .performance: model.performance.phase != .done
        case .duplicates: model.duplicates.phase != .done
        case .protection, .activity: true
        case .space: false
        }
    }

    /// The small title in the middle of the title bar. The opening screens carry their own large one instead.
    private var title: String? {
        let item = model.sidebarSelection
        switch item {
        case .overview:
            switch model.overviewPhase {
            case .home: return nil
            case .scanning: return "Scanning"
            case .running: return "Running"
            case .results, .done: return item.title
            }
        case .group(let group):
            return model.cleanUp(group).phase == .home ? nil : item.title
        case .space:
            return model.space.phase == .idle ? nil : item.title
        case .duplicates:
            return model.duplicates.phase == .idle ? nil : item.title
        case .apps:
            return model.apps.phase == .idle ? nil : item.title
        case .performance:
            return model.performance.phase == .idle ? nil : item.title
        case .protection:
            return model.protection.phase == .idle ? nil : item.title
        case .activity:
            // Both of its pages carry their own large title.
            return nil
        }
    }
}
