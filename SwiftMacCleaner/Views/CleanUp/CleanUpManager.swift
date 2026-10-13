//
//  CleanUpManager.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The manager: a column of the clean-up's areas, and beside it everything found in the chosen one,
/// item by item. What is ticked anywhere in the clean-up is cleaned with the round button.
struct CleanUpManager: View {
    @Environment(CleanUpModel.self) private var cleanUp

    var body: some View {
        HStack(alignment: .top, spacing: Design.Spacing.xLarge) {
            CleanUpColumn()
                .frame(width: Design.Size.areaColumn)
            if let area = cleanUp.openArea {
                ScrollView {
                    AreaFindings(area: area, isPane: true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, Design.Spacing.pageHorizontal)
        .padding(.top, Design.Spacing.pageVertical)
        .frame(maxWidth: 1100)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .orbAction {
            CleanButton(size: cleanUp.cleanableSize(), hasUnknownSize: cleanUp.selectionHasUnknownSize) {
                cleanUp.review()
            }
        }
    }
}
