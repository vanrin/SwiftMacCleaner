//
//  MemoryDetail.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The Memory details: how hard macOS has to work to find memory, what it is taken up by, and the
/// apps that use the most.
struct MemoryDetail: View {
    let reading: MemoryReading?
    let consumers: [Consumer]
    /// Opens the app on the task that hands memory back.
    let freeUp: () -> Void

    var body: some View {
        VitalHeader(kind: .memory, note: reading.map { VitalFormat.installedMemory($0.total) } ?? "")
        VitalHeadline(figure: reading.map { VitalFormat.percent($0.pressure) } ?? "–", caption: "pressure") {
            VitalRing(fraction: reading?.pressure ?? 0, level: reading?.level ?? .normal, lineWidth: Design.Size.detailRingLine)
        } content: {
            VitalStatus(title: reading?.state.title ?? "Reading", detail: reading?.state.detail ?? "")
            if let reading {
                Text("\(VitalFormat.memoryShare(reading.used, of: reading.total)) in use")
                    .font(.callout)
                    .monospacedDigit()
                if reading.state == .critical {
                    Button("Free Up Memory…", action: freeUp)
                        .buttonStyle(.compactPill)
                        .help("Opens Performance on the task that hands memory back. It asks for your password")
                }
            }
        }
        if let reading {
            MemoryComposition(reading: reading)
            VitalFactGrid(facts: reading.facts)
        }
        ConsumerList(consumers: consumers, measure: .memory)
    }
}
