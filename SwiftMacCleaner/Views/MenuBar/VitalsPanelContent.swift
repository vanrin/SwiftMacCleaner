//
//  VitalsPanelContent.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What the details panel shows: one reading's details, cut to the panel's rounded shape.
struct VitalsPanelContent: View {
    let model: AppModel
    let kind: VitalKind
    let openMain: () -> Void
    /// Told how large the details came out, so the panel can fit itself around them.
    let sized: (CGSize) -> Void

    var body: some View {
        VitalDetailView(kind: kind, openMain: openMain)
            .environment(model)
            .clipShape(.rect(cornerRadius: Design.Radius.menuBarPanel))
            .fixedSize()
            .onGeometryChange(for: CGSize.self, of: \.size, action: sized)
    }
}
