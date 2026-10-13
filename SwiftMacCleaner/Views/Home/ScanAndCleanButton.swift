//
//  ScanAndCleanButton.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Scans and goes straight to the confirmation, with the Smart selection ticked.
struct ScanAndCleanButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button("Scan and Clean", action: model.scanAndClean)
            .buttonStyle(.pill)
            .fixedSize()
            .disabled(model.enabledAreas.isEmpty)
            .help("Scan everything, then show the confirmation with the Smart selection ticked")
    }
}
