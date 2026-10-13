//
//  DuplicatesView.swift
//  SwiftMacCleaner
//

import SwiftUI
import UniformTypeIdentifiers

/// Duplicates: files that are the same to the last byte, with a way to keep one copy of each. It has a
/// scan of its own, which the overview leaves alone: reading files to compare them takes a while.
struct DuplicatesView: View {
    @Environment(AppModel.self) private var model
    @State private var isStartingOver = false

    var body: some View {
        @Bindable var duplicates = model.duplicates
        Group {
            switch duplicates.phase {
            case .idle:
                DuplicatesIntro()
            case .scanning:
                DuplicatesScanning()
            case .results:
                DuplicatesResults()
            case .removing:
                DuplicatesRemoving()
            case .done:
                DuplicatesDone()
            }
        }
        .sheet(isPresented: $duplicates.showingReview) {
            DuplicatesReviewSheet()
        }
        .fileImporter(isPresented: $duplicates.showingFolderPicker, allowedContentTypes: [.folder], onCompletion: choose)
        .confirmsStartingOver($isStartingOver, from: .duplicates, in: model)
        .toolbar {
            if duplicates.phase == .results || duplicates.phase == .done {
                ToolbarItem {
                    StartOverButton(isAsking: $isStartingOver)
                        .help("Choose where to look again")
                }
            }
        }
    }

    private func choose(_ result: Result<URL, any Error>) {
        if case .success(let folder) = result {
            model.duplicates.choose(folder)
        }
    }
}
