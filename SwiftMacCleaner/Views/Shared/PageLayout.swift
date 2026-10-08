//
//  PageLayout.swift
//  SwiftMacCleaner
//

import SwiftUI

extension View {
    /// The shared page layout: padded, left-aligned, and not stretched across a very wide window.
    func pageLayout(maxWidth: CGFloat = 980) -> some View {
        self
            .padding(.horizontal, Design.Spacing.pageHorizontal)
            .padding(.vertical, Design.Spacing.pageVertical)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
    }
}
