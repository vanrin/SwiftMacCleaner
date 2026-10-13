//
//  VitalsPanelPlacement.swift
//  SwiftMacCleaner
//

import CoreGraphics
import Foundation

/// Where the details panel goes: beside the menu bar popover, their top edges level.
nonisolated enum VitalsPanelPlacement {
    /// - Parameters:
    ///   - size: How large the details are.
    ///   - popover: The popover's frame on the screen, y pointing up.
    ///   - screen: The part of the screen windows may use.
    ///   - gap: How far the panel stands from the popover.
    /// - Returns: The panel's frame: to the left of the popover, or to its right when the left has no room.
    static func frame(for size: CGSize, beside popover: CGRect, on screen: CGRect, gap: Double) -> CGRect {
        var x = popover.minX - gap - size.width
        if x < screen.minX { x = popover.maxX + gap }
        return CGRect(x: x, y: popover.maxY - size.height, width: size.width, height: size.height)
    }
}
