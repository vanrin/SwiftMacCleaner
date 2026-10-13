//
//  IntroLayout.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The opening screen of a part of the app: artwork centred in the left half, and in the right half a
/// title, what it does, and whatever needs choosing before the round button is pressed.
struct IntroLayout<Art: View, Details: View>: View {
    @ContentBuilder var art: Art
    @ContentBuilder var details: Details
    /// Where the pointer is over the screen, for artwork that turns towards it.
    @State private var pointer: CGPoint?

    var body: some View {
        HStack(spacing: 0) {
            art
                .environment(\.introPointer, pointer)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: Design.Spacing.section) {
                details
            }
            .frame(minWidth: Design.Size.introTextMinimum, maxWidth: Design.Size.introTextWidth, alignment: .leading)
            .padding(.trailing, Design.Spacing.xLarge)
            // The text takes the width it wants first; the artwork is centred in what is left.
            .layoutPriority(1)
        }
        .padding(.horizontal, Design.Spacing.pageHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(.intro)
        .onContinuousHover(coordinateSpace: .intro, perform: follow)
    }

    private func follow(_ phase: HoverPhase) {
        switch phase {
        case .active(let location): pointer = location
        case .ended: pointer = nil
        }
    }
}

extension CoordinateSpaceProtocol where Self == NamedCoordinateSpace {
    /// The whole of an opening screen.
    nonisolated static var intro: NamedCoordinateSpace { .named("intro") }
}

extension EnvironmentValues {
    /// Where the pointer is over an opening screen, in that screen's coordinates. Nil anywhere else.
    @Entry var introPointer: CGPoint?
}
