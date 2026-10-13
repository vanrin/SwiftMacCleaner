//
//  VitalHeadline.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The first thing in a reading's details: its ring with the figure in it, and what there is to say
/// about it beside the ring.
struct VitalHeadline<Ring: View, Content: View>: View {
    let figure: String
    /// The word under the figure for what it measures.
    let caption: String
    @ContentBuilder let ring: Ring
    @ContentBuilder let content: Content

    var body: some View {
        HStack(spacing: Design.Spacing.xLarge) {
            ring
                .frame(width: Design.Size.detailRing, height: Design.Size.detailRing)
                .overlay {
                    RingFigure(figure: figure, caption: caption)
                }
            VStack(alignment: .leading, spacing: Design.Spacing.small) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
