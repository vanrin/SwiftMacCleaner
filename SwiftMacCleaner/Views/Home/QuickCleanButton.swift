//
//  QuickCleanButton.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Scans, keeps only the Safe tier ticked, and goes straight to the confirmation.
struct QuickCleanButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button("Quick Clean, Safe only", action: model.quickClean)
            .buttonStyle(.pill)
            .fixedSize()
            .disabled(model.enabledAreas.isEmpty)
            .help("Scan everything, keep only what rebuilds itself ticked, then show the confirmation")
    }
}
