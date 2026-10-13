//
//  BatteryDetail.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The Battery details: how full it is, what it is doing, and what shape it is in.
struct BatteryDetail: View {
    /// Nil on a Mac without a battery, which has no tile to open these from.
    let reading: BatteryReading?

    var body: some View {
        VitalHeader(kind: .battery)
        VitalHeadline(figure: reading.map { VitalFormat.percent($0.charge) } ?? "–", caption: "charge") {
            VitalRing(fraction: reading?.charge ?? 0, level: reading?.level ?? .normal, lineWidth: Design.Size.detailRingLine)
        } content: {
            VitalStatus(title: reading?.title ?? "Reading", detail: reading?.detail ?? "")
        }
        VitalFactGrid(facts: reading?.facts ?? [])
    }
}
