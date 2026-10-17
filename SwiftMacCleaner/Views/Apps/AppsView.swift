//
//  AppsView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Applications: the installed apps, with a way to uninstall them whole, see which have an update, and
/// clear out the installers and files they left behind. It has a scan of its own, apart from the clean-up.
struct AppsView: View {
    @Environment(AppModel.self) private var model
    @State private var isStartingOver = false

    var body: some View {
        @Bindable var apps = model.apps
        Group {
            switch apps.phase {
            case .idle:
                AppsIntro()
            case .scanning:
                AppsScanning()
            case .summary:
                AppsSummary()
            case .managing:
                AppsManager()
            case .removing:
                AppsRemoving()
            case .done:
                AppsDone()
            }
        }
        .sheet(isPresented: $apps.showingReview) {
            AppsReviewSheet()
        }
        .confirmsStartingOver($isStartingOver, from: .apps, in: model)
        .toolbar {
            if apps.phase == .managing {
                ToolbarItem(placement: .navigation) {
                    Button("Summary", systemImage: "chevron.left", action: apps.showSummary)
                        .labelStyle(.titleBar)
                        .help("Back to what the scan found")
                }
            }
            if apps.phase == .summary || apps.phase == .managing || apps.phase == .done {
                ToolbarItem {
                    StartOverButton(item: .apps, isAsking: $isStartingOver)
                        .disabled(!apps.installing.isEmpty)
                        .help(apps.installing.isEmpty ? "Forget what this scan found and go back to the start of Applications" : "Homebrew is installing an update")
                }
            }
        }
    }
}
