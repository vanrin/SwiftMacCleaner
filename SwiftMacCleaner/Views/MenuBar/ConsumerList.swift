//
//  ConsumerList.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The apps that use the most of something, the largest first. It keeps room for a full list
/// whatever is in it, so the panel does not change height as apps come and go.
struct ConsumerList: View {
    let consumers: [Consumer]
    let measure: Consumer.Measure

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.small) {
            Text("Top consumers")
                .font(.callout)
                .bold()
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(consumers) { consumer in
                    ConsumerRow(consumer: consumer, measure: measure)
                }
            }
            .frame(height: Design.Size.consumerRow * Double(Consumer.listLength), alignment: .top)
            .overlay(alignment: .topLeading) {
                Text("Measuring")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .opacity(consumers.isEmpty ? 1 : 0)
                    .accessibilityHidden(!consumers.isEmpty)
            }
        }
    }
}
