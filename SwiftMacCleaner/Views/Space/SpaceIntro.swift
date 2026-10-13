//
//  SpaceIntro.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Largest Folders before a measurement: what it does, and whether to measure the home folder or the disk.
struct SpaceIntro: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        @Bindable var space = model.space
        let disk = model.disk
        IntroLayout {
            HeroOrb(
                segments: [
                    UsageSegment(id: "used", label: "In use", bytes: disk.used, color: theme.accent),
                    UsageSegment(id: "free", label: "Free", bytes: disk.free, color: .clear, isRemainder: true),
                ],
                total: disk.capacity
            ) {
                OrbFigure(value: ByteFormat.string(disk.used), caption: "in use")
            }
        } details: {
            IntroHeading(
                title: "Largest Folders",
                detail: "See where the space went, and find what the clean-up scan does not know about."
            )
            VStack(alignment: .leading, spacing: Design.Spacing.large) {
                FeatureBullet(glyph: Image(systemName: "ruler.fill"), text: "Every folder measured")
                FeatureBullet(glyph: Image(systemName: "chart.bar.fill"), text: "The biggest listed first")
                FeatureBullet(glyph: Image(systemName: "eye.fill"), text: "Only reads, never removes")
            }
            VStack(alignment: .leading, spacing: Design.Spacing.small) {
                Picker("What to measure", selection: $space.scope) {
                    ForEach(SpaceModel.Scope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .controlSize(.large)
                Text(space.scope == .home
                     ? "Your own files: projects, Library, Documents, Downloads and the rest of \(space.displayPath(space.home.path))."
                     : "Everything on \(disk.name): your home folder plus Applications, the system Library and other users.")
                    .foregroundStyle(.quiet)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .orbAction {
            Button("Measure", action: space.start)
                .buttonStyle(.orb)
                .accessibilityLabel("Measure \(space.scope.title)")
                .help("Measure \(space.scope.title). A full disk can take a few minutes.")
        }
    }
}
