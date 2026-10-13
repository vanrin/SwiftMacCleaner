//
//  ModuleHero.swift
//  SwiftMacCleaner
//

import SwiftUI

/// A part's icon on the glass disc that is the artwork of its screens. On an opening screen the
/// icon turns a little towards the pointer; with Reduce Motion on it stands still.
struct ModuleHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Where the pointer is on an opening screen, which is the only place it is followed.
    @Environment(\.introPointer) private var pointer
    private let item: SidebarItem
    private let isBusy: Bool
    /// The middle of the disc, in the opening screen's own coordinates.
    @State private var center = CGPoint.zero

    /// - Parameter isBusy: Work is under way, so the disc's glow breathes.
    init(_ item: SidebarItem, isBusy: Bool = false) {
        self.item = item
        self.isBusy = isBusy
    }

    var body: some View {
        let pull = pull
        HeroOrb(isBusy: isBusy) {
            ModuleIcon(symbol: item.icon, theme: item.theme, size: Design.Size.heroIcon,
                       depth: pull == nil ? Design.Depth.hero : Design.Depth.heroNear,
                       // The face looks at the pointer, so more of the far side comes into view.
                       lean: CGVector(dx: -(pull?.dx ?? 0) * 0.9, dy: 1 - (pull?.dy ?? 0) * 0.75))
                // A positive turn takes the top edge, or the right one, away from the viewer.
                .rotation3DEffect(.degrees(-(pull?.dy ?? 0) * Design.Depth.turn * 0.8), axis: (x: 1, y: 0, z: 0), perspective: 0.35)
                .rotation3DEffect(.degrees((pull?.dx ?? 0) * Design.Depth.turn), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
        }
        .onGeometryChange(for: CGPoint.self) { proxy in
            let frame = proxy.frame(in: .intro)
            return CGPoint(x: frame.midX, y: frame.midY)
        } action: { middle in
            center = middle
        }
        .animation(Design.Motion.iconTurn, value: pull)
    }

    /// How far the pointer is from the middle of the disc, from -1 to 1 each way. Nil when the
    /// pointer is not over the screen, or is not to be followed.
    private var pull: CGVector? {
        guard let pointer, !reduceMotion else { return nil }
        let reach = Design.Size.heroReach
        return CGVector(dx: min(max((pointer.x - center.x) / reach, -1), 1),
                        dy: min(max((pointer.y - center.y) / reach, -1), 1))
    }
}
