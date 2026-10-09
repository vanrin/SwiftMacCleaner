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

    var body: some View {
        @Bindable var cleanUp = cleanUp
        Group {
            switch cleanUp.phase {
            case .home:
                CleanUpIntro()
            case .scanning:
                ScanningView(title: "Scanning \(cleanUp.group.scope)")
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
                plan: cleanUp.plan, blocked: cleanUp.blockedSteps(in: cleanUp.plan), hasUnknownSize: cleanUp.planHasUnknownSize,
                clean: cleanUp.clean, copyScript: cleanUp.copyShellScript
            )
        }
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
                    Button("Rescan", systemImage: "arrow.clockwise", action: rescan)
                        .labelStyle(.titleBar)
                        .help("Look at \(cleanUp.group.scope) again")
                }
            }
        }
    }

    private func rescan() {
        model.scan(cleanUp.group)
    }
}
