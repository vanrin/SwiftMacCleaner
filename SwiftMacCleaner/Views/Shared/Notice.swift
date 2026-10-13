//
//  Notice.swift
//  SwiftMacCleaner
//

import SwiftUI

/// A panel with a short message and, sometimes, something to do about it.
struct Notice<Actions: View>: View {
    var symbol: String?
    /// The symbol turns the warning colour, for a message the user should not miss.
    var isWarning = false
    /// Tinted with the accent, for the one notice that offers to undo something.
    var isHighlighted = false
    let title: String
    let text: String
    @ContentBuilder var actions: Actions

    var body: some View {
        GlassPanel(isHighlighted: isHighlighted) {
            HStack(spacing: Design.Spacing.medium) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.title3)
                        .foregroundStyle(isWarning ? AnyShapeStyle(Design.Signal.warning) : AnyShapeStyle(.quiet))
                        .accessibilityHidden(true)
                }
                TitledDetail(title: title, detail: text, detailLineLimit: nil)
                Spacer(minLength: Design.Spacing.medium)
                actions
            }
            .padding(Design.Spacing.large)
        }
    }
}

extension Notice where Actions == EmptyView {
    init(symbol: String? = nil, isWarning: Bool = false, title: String, text: String) {
        self.init(symbol: symbol, isWarning: isWarning, title: title, text: text) {
            EmptyView()
        }
    }
}
