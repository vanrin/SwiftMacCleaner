//
//  HeroOrb.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The glass disc that is the artwork of a screen: a ring around the edge and the figure that matters in the middle.
struct HeroOrb<Center: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// What the ring is split into. Ignored while `progress` is set.
    var segments: [UsageSegment] = []
    var total: Int64 = 1
    /// From 0 to 1. When set, the ring shows how far along the work is instead of the segments.
    var progress: Double? = nil
    /// Work is under way, so the glow breathes.
    var isBusy = false
    var size = Design.Size.heroOrb
    @ContentBuilder var center: Center

    private var ringWidth: Double { size * 0.05 }

    var body: some View {
        ZStack {
            // The body of the disc: lit from the top left, like a lens.
            Circle()
                .fill(RadialGradient(colors: [.white.opacity(0.95), .white.opacity(0.62), .white.opacity(0.38)],
                                     center: UnitPoint(x: 0.3, y: 0.18), startRadius: 0, endRadius: size * 0.9))
                .strokeBorder(LinearGradient(colors: [Design.Surface.rim, Design.Surface.panelBorder],
                                             startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
                .shadow(color: Design.Ground.shadow.opacity(0.16), radius: size * 0.08, y: size * 0.05)
            // A second rim just inside the edge gives the glass its thickness.
            Circle()
                .strokeBorder(LinearGradient(colors: [Design.Ground.shadow.opacity(0.01), Design.Ground.shadow.opacity(0.1)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: ringWidth * 0.5)
                .padding(ringWidth * 0.35)
            ring
                .padding(ringWidth * 1.5)
            center
                .multilineTextAlignment(.center)
                .padding(ringWidth * 4.2)
        }
        .frame(width: size, height: size)
        .background {
            // The glow and the shadow reach past the disc without taking up room in the layout.
            Circle()
                .fill(RadialGradient(colors: [Design.Ground.bloom.opacity(0.9), Design.Ground.bloom.opacity(0)],
                                     center: .center, startRadius: size * 0.44, endRadius: size * 0.72))
                .frame(width: size * 1.44, height: size * 1.44)
                .phaseAnimator([1.0, 1.07]) { halo, scale in
                    // Reduce Motion keeps the glow still; the ring and the figure still show progress.
                    halo.scaleEffect(isBusy && !reduceMotion ? scale : 1)
                } animation: { _ in
                    Design.Motion.pulse
                }
        }
        .background(alignment: .bottom) {
            Ellipse()
                .fill(Design.Ground.shadow.opacity(0.3))
                .frame(width: size * 0.78, height: size * 0.12)
                .blur(radius: size * 0.06)
                .offset(y: size * 0.1)
        }
        .accessibilityElement(children: .combine)
    }

    @ContentBuilder
    private var ring: some View {
        if let progress {
            ProgressRing(fraction: progress, lineWidth: ringWidth)
        } else {
            RingGauge(segments: segments, total: total, lineWidth: ringWidth)
        }
    }
}
