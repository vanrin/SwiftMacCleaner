//
//  VitalTiles.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The row of readings on the menu bar popover: the processor, memory, and the battery on a Mac
/// that has one.
struct VitalTiles: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: Design.Spacing.small) {
            ForEach(model.vitals.kinds) { kind in
                VitalTile(kind: kind)
            }
        }
    }
}
