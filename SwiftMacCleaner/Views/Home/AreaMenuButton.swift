//
//  AreaMenuButton.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Says how many areas the scan will look at, and opens the list to tick or untick them.
struct AreaMenuButton: View {
    @Environment(AppModel.self) private var model
    /// The areas on offer: every area of the clean-up, or one clean-up's.
    var areas = Area.cleanUp
    @State private var isPresented = false

    var body: some View {
        let listed = areas.filter(model.isListed)
        Button(action: toggle) {
            Label("\(listed.count(where: model.isScanned)) of \(listed.count) areas", systemImage: "checklist")
        }
        .buttonStyle(.dropdown)
        .help("Choose what the scan looks at")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            AreaPickerPopover(areas: areas)
                .environment(model)
        }
    }

    private func toggle() {
        isPresented.toggle()
    }
}
