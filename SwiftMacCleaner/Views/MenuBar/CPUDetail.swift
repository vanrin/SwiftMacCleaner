//
//  CPUDetail.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The CPU details: who the processor's time goes to, how busy each core is, how warm the Mac is
/// running, how long it has been on, and the apps that use the most.
struct CPUDetail: View {
    @Environment(\.theme) private var theme
    /// Nil until two looks at the processor can be compared.
    let reading: CPUReading?
    let consumers: [Consumer]

    var body: some View {
        VitalHeader(kind: .cpu, note: reading?.chip ?? "")
        VitalHeadline(figure: reading.map { VitalFormat.percent($0.load) } ?? "–", caption: "load") {
            RingGauge(segments: [
                UsageSegment(id: "user", label: "User", bytes: parts(reading?.user), color: theme.accent),
                UsageSegment(id: "system", label: "System", bytes: parts(reading?.system), color: Design.Surface.secondShare),
            ], total: Self.whole, lineWidth: Design.Size.detailRingLine)
        } content: {
            LoadShare(color: theme.accent, share: reading?.user, label: "User")
            LoadShare(color: Design.Surface.secondShare, share: reading?.system, label: "System")
            LoadShare(color: Design.Surface.keeping, share: reading?.idle, label: "Idle")
        }
        CoreBars(groups: reading?.coreGroups ?? [])
        VitalFactGrid(facts: reading?.facts() ?? [])
        ConsumerList(consumers: consumers, measure: .cpu)
    }

    /// The ring takes whole numbers, so a share is handed to it in thousandths.
    private static let whole: Int64 = 1000

    private func parts(_ share: Double?) -> Int64 {
        Int64(((share ?? 0) * Double(Self.whole)).rounded())
    }
}
