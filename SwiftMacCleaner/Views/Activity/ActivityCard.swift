//
//  ActivityCard.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One card of My Activity: its name, what sits beside the name, and an explanation of how its figure
/// is counted behind a small button, for the cards whose figure needs one.
struct ActivityCard<Accessory: View, Content: View>: View {
    let title: String
    /// A count beside the name.
    var count: Int? = nil
    /// How the card's figure is counted, in a sentence or two.
    var info: String? = nil
    @ContentBuilder var accessory: Accessory
    @ContentBuilder var content: Content

    @State private var showsInfo = false

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: Design.Spacing.small) {
                HStack(spacing: Design.Spacing.small) {
                    Text(title)
                        .font(Design.Typeface.rowTitle)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                    if let count {
                        Badge(text: count.formatted())
                    }
                    Spacer(minLength: 0)
                    accessory
                    if let info {
                        Button(action: toggleInfo) {
                            Image(systemName: "info")
                                .font(.caption.weight(.bold))
                                .frame(width: Design.Size.infoButton, height: Design.Size.infoButton)
                                .foregroundStyle(showsInfo ? AnyShapeStyle(.white) : AnyShapeStyle(.quiet))
                                .background(showsInfo ? Design.Ink.primary : Design.Surface.quietButton, in: .circle)
                                .contentShape(.circle)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("How \(title) is counted")
                        .popover(isPresented: $showsInfo, arrowEdge: .bottom) {
                            VStack(alignment: .leading, spacing: Design.Spacing.small) {
                                Text("How this is counted")
                                    .font(.headline)
                                Text(info)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(Design.Spacing.large)
                            .frame(width: Design.Size.noticeWidth, alignment: .leading)
                        }
                    }
                }
                .frame(minHeight: Design.Size.infoButton)
                content
            }
            .padding(.horizontal, Design.Spacing.large + Design.Spacing.tight + 2)
            .padding(.vertical, Design.Spacing.large + Design.Spacing.tight)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .contain)
    }

    private func toggleInfo() {
        showsInfo.toggle()
    }
}

extension ActivityCard where Accessory == EmptyView {
    init(title: String, count: Int? = nil, info: String? = nil, @ContentBuilder content: () -> Content) {
        self.init(title: title, count: count, info: info, accessory: { EmptyView() }, content: content)
    }
}

/// The leading figure of a card, with what it counts after it in quieter type.
struct ActivityFigure: View {
    let value: String
    var unit: String? = nil
    /// Nothing has been counted yet, so the figure is a word in the third ink.
    var isEmpty = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Design.Spacing.small) {
            Text(value)
                .font(Design.Typeface.cardFigure)
                .foregroundStyle(isEmpty ? AnyShapeStyle(Design.Ink.tertiary) : AnyShapeStyle(.primary))
                .contentTransition(.numericText())
            if let unit {
                Text(unit)
                    .font(Design.Typeface.tileBody.weight(.medium))
                    .foregroundStyle(.quiet)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .combine)
    }
}

/// What came on top this month, under a figure: a small rising mark and the amount.
struct MonthGain: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "arrowtriangle.up.fill")
                .imageScale(.small)
        }
        .labelStyle(.monthGain)
        .font(.callout.weight(.semibold))
        .foregroundStyle(Design.Signal.safe)
        .lineLimit(1)
    }
}

private struct MonthGainLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Design.Spacing.tight + 2) {
            configuration.icon
            configuration.title
        }
    }
}

private extension LabelStyle where Self == MonthGainLabelStyle {
    static var monthGain: MonthGainLabelStyle { MonthGainLabelStyle() }
}
