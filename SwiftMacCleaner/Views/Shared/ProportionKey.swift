//
//  ProportionKey.swift
//  SwiftMacCleaner
//

import SwiftUI

/// How much of a `ProportionalRow` a view asks for, in the same unit as the row's total.
nonisolated struct ProportionKey: LayoutValueKey {
    static let defaultValue = 0.0
}
