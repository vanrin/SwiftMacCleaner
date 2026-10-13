//
//  VitalsPanelView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The view the details panel holds. Its window is never the key one, so a click on a button in it
/// has to count as the click itself, not as the one that wakes the window.
final class VitalsPanelView: NSHostingView<VitalsPanelContent> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
