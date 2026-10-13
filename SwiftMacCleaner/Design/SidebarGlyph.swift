//
//  SidebarGlyph.swift
//  SwiftMacCleaner
//

import SwiftUI

/// A sidebar icon. At rest it wears graphite, like every other; under the pointer and when its
/// entry is chosen it lifts a little off its copy and takes its part's own colours.
struct SidebarGlyph: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let symbol: ImageResource
    let theme: Theme
    var isSelected = false
    var isHovered = false
    var isPressed = false
    /// Its part of the scan is under way, so it breathes.
    var isBusy = false

    var body: some View {
        icon(depth: depth)
            .animation(reduceMotion ? nil : isPressed ? Design.Motion.press : Design.Motion.iconLift, value: depth)
            // A scan under way: the icon breathes. Lifting and settling was tried and dropped, since
            // every frame of a lift draws the icon again, which took a fifth of a processor core
            // for as long as a scan ran. Fading a picture that is already drawn costs next to nothing.
            .phaseAnimator(isBusy ? [1.0, 0.5] : [1.0]) { content, strength in
                content.opacity(strength)
            } animation: { _ in
                Design.Motion.iconBusy
            }
            .frame(width: Design.Size.sidebarGlyph, height: Design.Size.sidebarGlyph)
    }

    /// With Reduce Motion on nothing lifts or sinks: the chosen entry sits a little deeper, and that is all.
    private var depth: Double {
        if reduceMotion { return isSelected ? Design.Depth.selected : Design.Depth.rest }
        if isPressed { return Design.Depth.pressed }
        if isHovered { return Design.Depth.hover }
        return isSelected ? Design.Depth.selected : Design.Depth.rest
    }

    /// In its own colours rather than graphite.
    private var isLit: Bool {
        isSelected || isHovered || theme == .graphite
    }

    /// Graphite underneath, and the part's own colours fading in over it.
    private func icon(depth: Double) -> some View {
        ZStack {
            if theme != .graphite {
                ModuleIcon(symbol: symbol, theme: .graphite, depth: depth)
                    .animation(Design.Motion.iconTint) { $0.opacity(isLit ? 0 : 1) }
            }
            ModuleIcon(symbol: symbol, theme: theme, depth: depth)
                .animation(Design.Motion.iconTint) { $0.opacity(isLit ? 1 : 0) }
        }
    }
}
