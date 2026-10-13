//
//  VitalsPanelAnchor.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Sits unseen in the menu bar popover and stands the details panel beside the popover's window. A
/// second window is the only way to have the details next to the popover: the popover itself is
/// one window, laid out and placed by macOS.
struct VitalsPanelAnchor: NSViewRepresentable {
    let model: AppModel
    /// The reading whose details are open, if any.
    let detail: VitalKind?
    let openMain: () -> Void

    func makeCoordinator() -> VitalsPanelController {
        VitalsPanelController(model: model)
    }

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.show(detail, beside: view.window, openMain: openMain)
    }

    static func dismantleNSView(_ view: NSView, coordinator: VitalsPanelController) {
        coordinator.close()
    }
}
