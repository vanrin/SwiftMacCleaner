//
//  SpaceTrail.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The path from the measured root to the folder on screen. Each step goes back up to it.
struct SpaceTrail: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let space = model.space
        ScrollView(.horizontal) {
            HStack(spacing: Design.Spacing.tight) {
                ForEach(space.trail.enumerated(), id: \.element.id) { index, _ in
                    let isCurrent = index == space.trail.count - 1
                    HStack(spacing: Design.Spacing.tight) {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .opacity(index > 0 ? 1 : 0)
                            .accessibilityHidden(true)
                        Button(space.title(at: index)) {
                            space.goBack(to: index)
                        }
                        .buttonStyle(.borderless)
                        .bold(isCurrent)
                        .foregroundStyle(isCurrent ? AnyShapeStyle(.primary) : AnyShapeStyle(.quiet))
                        .disabled(isCurrent)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}
