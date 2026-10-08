//
//  GlassPanel.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// A frosted panel the backdrop glows through: the surface every group of rows sits on.
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
        }
    }

    private var fill: AnyShapeStyle {
        if reduceTransparency {
            AnyShapeStyle(Design.Surface.solidPanel)
        } else if isHighlighted {
            AnyShapeStyle(LinearGradient(colors: [theme.accent.opacity(0.34), theme.accent.opacity(0.12)],
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
            theme.accent.opacity(0.6)
        } else {
            Design.Surface.panelBorder
        }
    }
}
