//
//  StartOverButton.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The title bar button that leaves a scan's results for the part's opening screen. It only asks:
/// the screen it belongs to confirms and then does it, with `confirmsStartingOver`. The question is
/// put by the screen and not by the button, because a view in the title bar cannot be relied on to
/// present one.
struct StartOverButton: View {
    @Binding var isAsking: Bool

    var body: some View {
        Button("Start Over", systemImage: "arrow.counterclockwise", action: ask)
            .labelStyle(.titleBar)
    }

    private func ask() {
        isAsking = true
    }
}

extension View {
    /// Asks before a scan's results are left behind, since they are forgotten, and then starts over
    /// from that entry of the sidebar. The model decides how far that reaches: one part, or every
    /// part when the scan was the overview's. The question says which.
    func confirmsStartingOver(_ isPresented: Binding<Bool>, from item: SidebarItem, in model: AppModel) -> some View {
        confirmationDialog("Start over?", isPresented: isPresented) {
            Button("Start Over") {
                model.startOver(from: item)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(model.startOverWarning(from: item))
        }
    }
}
