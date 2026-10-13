//
//  ConsumerRow.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One of the apps that use the most: its icon, its name, what it uses, and a way to quit it.
struct ConsumerRow: View {
    let consumer: Consumer
    let measure: Consumer.Measure

    var body: some View {
        HStack(spacing: Design.Spacing.medium) {
            AppIconView(url: consumer.url, size: Design.Size.consumerIcon)
            Text(consumer.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: Design.Spacing.small)
            Text(consumer.text(for: measure))
                .bold()
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
            ConsumerAction(consumer: consumer)
        }
        .frame(height: Design.Size.consumerRow)
    }
}
