//
//  CleanUpView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One clean-up, such as System Clean Up, from start to finish: its opening screen, its scan, what it
/// found with a manager for the details, the confirmation, the clean and its receipt. It reads its
/// clean-up from the environment, where the detail view puts it, so the same screens serve every group.
struct CleanUpView: View {
    @Environment(AppModel.self) private var model
    @Environment(CleanUpModel.self) private var cleanUp
    @State private var isStartingOver = false

    var body: some View {
        @Bindable var cleanUp = cleanUp
        Group {
            switch cleanUp.phase {
            case .home:
                CleanUpIntro()
            case .scanning:
                ScanningView(title: model.scanTitle(of: .group(cleanUp.group)))
            case .results:
                if cleanUp.openArea != nil {
                    CleanUpManager()
                } else {
                    CleanUpSummary()
                }
            case .cleaning:
                CleaningView(progress: cleanUp.cleanProgress)
            case .done:
                if let outcome = cleanUp.outcome {
                    DoneView(outcome: outcome, remaining: cleanUp.foundSize, showResults: cleanUp.showResults)
                }
            }
        }
        .sheet(isPresented: $cleanUp.showingReview) {
            ReviewSheet(
                plan: cleanUp.plan, blocked: cleanUp.blockedSteps(in: cleanUp.plan),
                waiting: cleanUp.waitingReasons(in: cleanUp.reviewArea), blockingApps: cleanUp.blockingApps(in: cleanUp.reviewArea),
                quit: cleanUp.quit, hasUnknownSize: cleanUp.planHasUnknownSize,
                clean: cleanUp.clean, copyScript: cleanUp.copyShellScript
            )
        }
        .confirmsStartingOver($isStartingOver, from: .group(cleanUp.group), in: model)
        .toolbar {
            if cleanUp.phase == .results, cleanUp.openArea != nil {
                ToolbarItem(placement: .navigation) {
                    Button("Summary", systemImage: "chevron.left", action: cleanUp.showResults)
                        .labelStyle(.titleBar)
                        .help("Back to what the scan found")
                }
            }
            if cleanUp.phase == .results || cleanUp.phase == .done {
                ToolbarItem {
                    StartOverButton(isAsking: $isStartingOver)
                        .help("Forget what this scan found and go back to the start of \(cleanUp.group.title)")
                }
            }
        }
    }
}
