//
//  ActivityPage.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The cards of My Activity: this Mac, what was cleaned, what else was done, what is worth doing
/// next, how the Protection check found it, and the newest runs. Three to a row in a wide window,
/// two to a row in a narrow one. In a short window the rows give way a little before the page scrolls.
struct ActivityPage: View {
    @Environment(AppModel.self) private var model
    @State private var width = Design.Size.activityThreeColumns
    @State private var height = Design.Size.activityTopRow + Design.Size.activityBottomRow + 200
    /// How tall the title above the cards stands, as laid out.
    @State private var headingHeight: Double = 64

    private static let bottomRoom = Design.Spacing.large

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Design.Spacing.large) {
                HStack(alignment: .lastTextBaseline, spacing: Design.Spacing.large) {
                    Text("My Activity")
                        .font(Design.Typeface.heroTitle)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                    Text(since)
                        .foregroundStyle(.quiet)
                        .lineLimit(1)
                }
                .onGeometryChange(for: Double.self) { proxy in
                    proxy.size.height
                } action: { newHeight in
                    headingHeight = newHeight
                }
                cards
            }
            .padding(.horizontal, Design.Spacing.pageHorizontal)
            .padding(.top, Design.Spacing.small)
            .padding(.bottom, Self.bottomRoom)
        }
        // Measured on the scroll view, not on the cards, whose width follows from this.
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            width = size.width - 2 * Design.Spacing.pageHorizontal
            height = size.height
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    /// How tall the two rows of three are: as drawn when the window has room, shorter in a short
    /// window, never shorter than their least.
    private var rows: (top: Double, bottom: Double) {
        let top = Design.Size.activityTopRow, bottom = Design.Size.activityBottomRow
        // Above the cards: the padding, the title and the space under it. Between and below them: the
        // gap between the rows and the padding at the foot.
        let room = height - Design.Spacing.small - headingHeight - 2 * Design.Spacing.large - Self.bottomRoom
        guard room < top + bottom else { return (top, bottom) }
        let shortTop = max(Design.Size.activityTopRowMinimum, room * top / (top + bottom))
        return (shortTop, max(Design.Size.activityBottomRowMinimum, room - shortTop))
    }

    private var since: String {
        guard let since = model.activity.since else { return "Nothing recorded yet" }
        return "Since \(since.formatted(.dateTime.day().month(.wide).year()))"
    }

    @ContentBuilder
    private var cards: some View {
        let gap = Design.Spacing.large
        if width >= Design.Size.activityThreeColumns {
            let unit = (width - 2 * gap) / (Design.Size.activityLeadShare + 2)
            let rows = rows
            let listRoom = rows.bottom - Design.Size.activityCardChrome
            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    ThisMacCard()
                        .frame(width: unit * Design.Size.activityLeadShare)
                    CleanedCard()
                        .frame(width: unit)
                    DoneSoFarCard()
                        .frame(width: unit)
                }
                .frame(height: rows.top)
                HStack(spacing: gap) {
                    NextStepsCard(rowHeight: min(Design.Size.suggestionRow, listRoom / 3))
                        .frame(width: unit * Design.Size.activityLeadShare)
                    ProtectionCard()
                        .frame(width: unit)
                    RecentCard(rows: max(1, min(4, Int(listRoom / Design.Size.activityRow))))
                        .frame(width: unit)
                }
                .frame(height: rows.bottom)
            }
        } else {
            let half = (width - gap) / 2
            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    ThisMacCard()
                        .frame(width: half)
                    CleanedCard()
                        .frame(width: half)
                }
                .frame(height: Design.Size.activityTopRow)
                HStack(spacing: gap) {
                    DoneSoFarCard()
                        .frame(width: half)
                    ProtectionCard()
                        .frame(width: half)
                }
                .frame(height: Design.Size.activityTopRow)
                HStack(spacing: gap) {
                    NextStepsCard()
                        .frame(width: half)
                    RecentCard()
                        .frame(width: half)
                }
                .frame(height: Design.Size.activityBottomRow)
            }
        }
    }
}
