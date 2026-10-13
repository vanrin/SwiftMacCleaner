//
//  VitalDetailView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The details of one reading, as they stand beside the menu bar popover.
struct VitalDetailView: View {
    @Environment(AppModel.self) private var model
    let kind: VitalKind
    /// Brings the main window forward, for the one button here that leads into the app.
    let openMain: () -> Void

    var body: some View {
        let readings = model.vitals.readings
        VStack(alignment: .leading, spacing: Design.Spacing.large) {
            switch kind {
            case .cpu:
                CPUDetail(reading: readings.cpu, consumers: readings.byCPU)
            case .memory:
                MemoryDetail(reading: readings.memory, consumers: readings.byMemory, freeUp: freeUpMemory)
            case .battery:
                BatteryDetail(reading: readings.battery)
            }
        }
        .menuBarSurface()
    }

    private func freeUpMemory() {
        openMain()
        model.freeUpMemory()
    }
}
