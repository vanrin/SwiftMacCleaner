//
//  CleanUpIntro.swift
//  SwiftMacCleaner
//

import SwiftUI

/// A clean-up before its scan: what it covers on this Mac, which of that to look at, and the button that starts it.
struct CleanUpIntro: View {
    @Environment(AppModel.self) private var model
    @Environment(CleanUpModel.self) private var cleanUp

    var body: some View {
        let group = cleanUp.group
        let areas = model.areas(in: group)
        IntroLayout {
            HeroOrb {
                Image(group.glyph)
                    .font(Design.Typeface.orbFigure)
                    .accessibilityHidden(true)
            }
        } details: {
            IntroHeading(title: group.title, detail: group.intro)
            // A few areas stand in a list; the developer areas, up to eight, share two columns.
            if areas.count > 4 {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                          alignment: .leading, spacing: Design.Spacing.medium) {
                    ForEach(areas) { area in
                        FeatureBullet(glyph: Image(area.glyph), text: area.title, isCompact: true)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: Design.Spacing.large) {
                    ForEach(areas) { area in
                        FeatureBullet(glyph: Image(area.glyph), text: area.title)
                    }
                }
            }
            Text(group.promise)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            // Which of its areas the scan looks at; a clean-up of one area has nothing to choose.
            if group.areas.count > 1 {
                AreaMenuButton(areas: group.areas)
            }
        }
        .orbAction {
            Button("Scan", action: scan)
                .buttonStyle(.orb)
                .keyboardShortcut(.defaultAction)
                .disabled(!group.areas.contains(where: model.isScanned))
                .accessibilityLabel("Scan \(group.scope)")
                .help("Measure \(group.scope). Nothing is removed.")
        }
    }

    private func scan() {
        model.scan(cleanUp.group)
    }
}
