//
//  MenuBarShowcase.swift
//  SwiftMacCleaner
//

import SwiftUI

#if DEBUG
/// The menu bar popover with a reading's details beside it, drawn in the main window for
/// `--demo menubar`, where both can be looked at without going through the menu bar.
struct MenuBarShowcase: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .top, spacing: Design.Size.menuBarGap) {
            if let kind = model.vitals.detail {
                VitalDetailView(kind: kind, openMain: {})
                    .clipShape(.rect(cornerRadius: Design.Radius.menuBarPanel))
            }
            MenuBarView()
                .clipShape(.rect(cornerRadius: Design.Radius.menuBarPanel))
        }
        .padding(Design.Spacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .background(Design.Surface.solidPanel)
        .background(.gray)
    }
}
#endif
