//
//  VitalTint.swift
//  SwiftMacCleaner
//

import SwiftUI

extension VitalLevel {
    /// The colour of a ring at this level: the palette's accent while all is well, then the two
    /// colours the app keeps for what wants a look and what wants doing.
    func tint(in theme: Theme) -> Color {
        switch self {
        case .normal: theme.accent
        case .raised: Design.Signal.review
        case .high: Design.Signal.warning
        }
    }
}
