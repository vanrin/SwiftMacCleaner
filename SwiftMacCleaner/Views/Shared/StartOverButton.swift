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
    /// Asks before a scan's results are left behind, since they are forgotten.
    ///
    /// - Parameter message: What is forgotten and what stays, in a sentence or two.
    func confirmsStartingOver(_ isPresented: Binding<Bool>, message: String, perform action: @escaping () -> Void) -> some View {
        confirmationDialog("Start over?", isPresented: isPresented) {
            Button("Start Over", action: action)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(message)
        }
    }
}
