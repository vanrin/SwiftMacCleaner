//
//  VitalsPanel.swift
//  SwiftMacCleaner
//

import AppKit

/// The window a reading's details open in. It stands beside the menu bar popover and never takes
/// the keyboard from it: the popover closes the moment it stops being the key window.
final class VitalsPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
