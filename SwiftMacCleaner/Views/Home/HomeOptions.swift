//
//  HomeOptions.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What can be chosen before a scan: which areas it looks at, and the scan that goes straight on to
/// the confirmation.
/// Side by side where there is room, one above the other where there is not.
struct HomeOptions: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Design.Spacing.medium) {
                AreaMenuButton()
                ScanAndCleanButton()
            }
            VStack(alignment: .leading, spacing: Design.Spacing.medium) {
                AreaMenuButton()
                ScanAndCleanButton()
            }
        }
    }
}
