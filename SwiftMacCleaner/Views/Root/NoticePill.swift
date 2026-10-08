//
//  NoticePill.swift
//  SwiftMacCleaner
//

import SwiftUI

/// A short notice in the title bar. Clicking it opens the explanation and what can be done about it.
struct NoticePill<Actions: View>: View {
    let title: String
    let symbol: String
    let text: String
    @ContentBuilder var actions: Actions
    @State private var isPresented = false

    var body: some View {
        Button(title, systemImage: symbol, action: toggle)
            .labelStyle(.titleBar)
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: Design.Spacing.medium) {
                    Text(title)
                        .font(.headline)
                    Text(text)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: Design.Spacing.small) {
                        actions
                    }
                }
                .padding(Design.Spacing.large)
                .frame(width: Design.Size.noticeWidth, alignment: .leading)
            }
    }

    private func toggle() {
        isPresented.toggle()
    }
}
