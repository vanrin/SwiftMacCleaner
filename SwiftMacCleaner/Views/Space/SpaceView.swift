//
//  SpaceView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Largest Folders: measures a whole folder tree and lets the user walk down into the biggest parts.
/// It only reads. Removing things stays with the clean-up scans, which know what each thing is.
struct SpaceView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let space = model.space
        Group {
            switch space.phase {
            case .idle:
                SpaceIntro()
            case .measuring:
                SpaceMeasuring()
            case .done:
                if let node = space.current {
                    SpaceBrowser(node: node)
                }
            }
        }
        .toolbar {
            if space.phase == .done {
                ToolbarItem {
                    Button("Start Over", systemImage: "arrow.counterclockwise", action: space.reset)
                        .labelStyle(.titleBar)
                        .help("Choose what to measure again")
                }
            }
        }
    }
}
