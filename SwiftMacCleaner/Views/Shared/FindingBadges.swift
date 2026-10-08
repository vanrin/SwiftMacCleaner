//
//  FindingBadges.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The badges a finding earns: what it waits for, and whether it needs a password.
struct FindingBadges: View {
    let finding: Finding
    let active: InUseCheck?

    var body: some View {
        if let active {
            Badge(text: active.badge, style: .waits)
        }
        if finding.method == .adminCommand {
            Badge(text: "Asks for your password", style: .password)
        }
    }
}
