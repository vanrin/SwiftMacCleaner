//
//  SpaceBrowser.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One measured folder: how big it is, and what is inside, largest first.
struct SpaceBrowser: View {
    @Environment(AppModel.self) private var model
    let node: SpaceNode

    var body: some View {
        let space = model.space
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Design.Spacing.xLarge) {
                if space.trail.count > 1 {
                    SpaceTrail()
                }
                SpaceHeader(node: node)
                GlassPanel {
                    ForEach(node.children) { child in
                        SpaceRow(node: child, parentSize: node.size, showsDivider: child.id != node.children.first?.id)
                    }
                    if node.smallerItemsSize > 0 {
                        SmallerItemsRow(node: node)
                    }
                }
            }
            .pageLayout()
        }
    }
}
