//
//  GlassPanel.swift
//  SwiftMacCleaner
//

import SwiftUI

/// A panel of white glass raised off the ground: the surface every group of rows sits on.
struct GlassPanel<Content: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    /// Tinted with the accent, for the one panel on a screen that asks for a decision.
    var isHighlighted = false
    var cornerRadius = Design.Radius.panel
    @ContentBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(fill)
                .strokeBorder(border)
                .shadow(color: Design.Surface.shadow, radius: 16, y: 8)
        }
    }

    private var fill: AnyShapeStyle {
        if reduceTransparency {
            AnyShapeStyle(Design.Surface.solidPanel)
        } else if isHighlighted {
            AnyShapeStyle(LinearGradient(colors: [theme.accent.opacity(0.26), theme.accent.opacity(0.1)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
        } else {
            AnyShapeStyle(LinearGradient(colors: [Design.Surface.panelTop, Design.Surface.panelBottom],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    private var border: Color {
        if contrast == .increased {
            Design.Surface.strongBorder
        } else if isHighlighted {
            theme.accent.opacity(0.5)
        } else {
            Design.Surface.panelBorder
        }
    }
}
