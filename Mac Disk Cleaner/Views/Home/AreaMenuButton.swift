//
//  AreaMenuButton.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// Says how many areas the scan will look at, and opens the list to tick or untick them.
struct AreaMenuButton: View {
    @Environment(AppModel.self) private var model
    @State private var isPresented = false

    var body: some View {
        Button(action: toggle) {
            Label("\(model.enabledAreas.count) of \(model.listedAreas.count) areas", systemImage: "checklist")
        }
        .buttonStyle(.dropdown)
        .help("Choose what the scan looks at")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            AreaPickerPopover()
                .environment(model)
        }
    }

    private func toggle() {
        isPresented.toggle()
    }
}
