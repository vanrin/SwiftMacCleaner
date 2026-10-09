//
//  PerformanceView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Performance: the maintenance tasks worth running, the apps that open at login, and the launch agents
/// and daemons that run on their own. It has a scan of its own, apart from the clean-up.
struct PerformanceView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var performance = model.performance
        Group {
            switch performance.phase {
            case .idle:
                PerformanceIntro()
            case .scanning:
                PerformanceScanning()
            case .summary:
                PerformanceSummary()
            case .managing:
                PerformanceManager()
            case .running:
                PerformanceRunning()
            case .done:
                PerformanceDone()
            }
        }
        .sheet(isPresented: $performance.showingReview) {
            PerformanceReviewSheet()
        }
        .toolbar {
            if performance.phase == .managing {
                ToolbarItem(placement: .navigation) {
                    Button("Summary", systemImage: "chevron.left", action: performance.showSummary)
                        .labelStyle(.titleBar)
                        .help("Back to what the scan found")
                }
            }
            if performance.phase == .summary || performance.phase == .managing || performance.phase == .done {
                ToolbarItem {
                    Button("Rescan", systemImage: "arrow.clockwise", action: performance.startScan)
                        .labelStyle(.titleBar)
                        .help("Look at the tasks, login items and background items again")
                }
            }
        }
    }
}
