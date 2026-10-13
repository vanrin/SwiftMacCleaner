//
//  OverviewView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The overview from start to finish: the home screen, one scan that runs every part, what each part
/// found side by side, and one run through the ticked ones with its receipt.
struct OverviewView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Group {
            switch model.overviewPhase {
            case .home:
                HomeView()
            case .scanning:
                OverviewScanning()
            case .results:
                OverviewSummary()
            case .running:
                CleaningView(progress: model.runProgress)
            case .done:
                if let outcome = model.overviewOutcome {
                    DoneView(outcome: outcome, remaining: model.foundSize, showResults: model.showOverviewResults,
                             doneDetail: model.performance.receiptDetail)
                }
            }
        }
        .sheet(isPresented: $model.showingOverviewReview) {
            ReviewSheet(
                verb: "Run",
                plan: model.runPlan, blocked: model.runBlockedSteps,
                waiting: model.runWaitingItems, blockingApps: model.runBlockingApps, quit: model.openApps.quit,
                hasUnknownSize: model.runHasUnknownSize,
                clean: { model.run() }, copyScript: model.copyRunScript
            )
        }
        .toolbar {
            if model.overviewPhase == .results || model.overviewPhase == .done {
                ToolbarItem {
                    Button("Rescan", systemImage: "arrow.clockwise", action: model.startScan)
                        .labelStyle(.titleBar)
                        .help("Run every part's scan again")
                }
            }
        }
    }
}
