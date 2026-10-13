//
//  OverviewTile.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One part of the app on the overview: a box to tick when Run should act on it, the figure that
/// matters, and a way into the part itself.
struct OverviewTile: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let part: SidebarItem
    @State private var isHovered = false

    var body: some View {
        let figure = model.overviewFigure(of: part)
        let canRun = model.hasWork(part)
        GlassPanel(cornerRadius: Design.Radius.tile) {
            VStack(alignment: .leading, spacing: Design.Spacing.small) {
                HStack(alignment: .top, spacing: Design.Spacing.medium) {
                    if canRun {
                        Toggle(isOn: model.inclusion(of: part)) {
                            Text(part.title)
                                .font(Design.Typeface.rowTitle)
                                .lineLimit(1)
                        }
                        .toggleStyle(.check)
                    } else {
                        Text(part.title)
                            .font(Design.Typeface.rowTitle)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    // The part's icon lifts a little while the pointer is over its tile.
                    ModuleIcon(symbol: part.icon, theme: part.theme, size: Design.Size.tileIcon,
                               depth: isHovered && !reduceMotion ? Design.Depth.hover : Design.Depth.tile)
                        .animation(Design.Motion.iconLift, value: isHovered)
                }
                Spacer(minLength: 0)
                // The figure and its line sit at the bottom left, the way in at the bottom right.
                HStack(alignment: .bottom, spacing: Design.Spacing.medium) {
                    VStack(alignment: .leading, spacing: Design.Spacing.tight) {
                        Text(figure.value)
                            .font(Design.Typeface.tileTitle)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .contentTransition(.numericText())
                        Text(figure.caption)
                            .font(Design.Typeface.tileBody)
                            .foregroundStyle(.quiet)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        if let selection = figure.selection {
                            Text(selection)
                                .font(Design.Typeface.tileBody)
                                .bold(figure.isSelected)
                                .foregroundStyle(figure.isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.quiet))
                                .lineLimit(1)
                                .contentTransition(.numericText())
                        }
                    }
                    Spacer(minLength: 0)
                    Button("Review", action: open)
                        .buttonStyle(.pill)
                        .fixedSize()
                        .disabled(!model.hasResults(part))
                        .accessibilityLabel("Review \(part.title)")
                }
            }
            .padding(Design.Spacing.large)
            .frame(height: Design.Size.tileHeight, alignment: .topLeading)
        }
        .onHover(perform: hover)
        .accessibilityElement(children: .contain)
    }

    private func hover(_ isInside: Bool) {
        isHovered = isInside
    }

    private func open() {
        model.select(part)
    }
}
