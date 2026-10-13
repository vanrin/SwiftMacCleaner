//
//  ConsumerAction.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The end of a row of the apps that use the most: a Quit button for an app that can be asked to
/// quit, and a word in its place for a part of macOS.
struct ConsumerAction: View {
    @Environment(AppModel.self) private var model
    let consumer: Consumer

    var body: some View {
        ZStack {
            Button("Quit", action: quit)
                .buttonStyle(.compactPill)
                .accessibilityLabel("Quit \(consumer.name)")
                .help("Asks \(consumer.name) to quit, as its own Quit command would. It can still ask about unsaved work")
                .opacity(consumer.canQuit ? 1 : 0)
                .disabled(!consumer.canQuit)
                .accessibilityHidden(!consumer.canQuit)
            Text("macOS")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .opacity(consumer.isSystem ? 1 : 0)
                .accessibilityHidden(!consumer.isSystem)
        }
        .frame(width: Design.Size.consumerAction)
    }

    private func quit() {
        model.vitals.quit(consumer)
    }
}
