//
//  VitalsPanelController.swift
//  SwiftMacCleaner
//

import AppKit
import SwiftUI

/// Keeps the details panel beside the menu bar popover: shows it when a tile is pressed, fits it to
/// what it holds, and takes it away with the popover.
final class VitalsPanelController {
    private let model: AppModel
    private var panel: VitalsPanel?
    private var shown: VitalKind?
    private weak var popover: NSWindow?

    init(model: AppModel) {
        self.model = model
    }

    /// Shows the details of `kind` beside `window`, or closes the panel when either is missing.
    func show(_ kind: VitalKind?, beside window: NSWindow?, openMain: @escaping () -> Void) {
        guard let kind, let window else { return close() }
        guard kind != shown || panel?.parent !== window else { return }
        let panel = panel ?? makePanel()
        self.panel = panel
        popover = window
        shown = kind
        let content = VitalsPanelContent(model: model, kind: kind, openMain: openMain) { [weak self] size in
            self?.fit(to: size)
        }
        if let view = panel.contentView as? VitalsPanelView {
            view.rootView = content
        } else {
            panel.contentView = VitalsPanelView(rootView: content)
        }
        panel.contentView?.layoutSubtreeIfNeeded()
        fit(to: panel.contentView?.fittingSize ?? .zero)
        if panel.parent !== window {
            panel.level = window.level
            window.addChildWindow(panel, ordered: .above)
        }
    }

    func close() {
        guard let panel, shown != nil else { return }
        shown = nil
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
    }

    private func fit(to size: CGSize) {
        guard let panel, let popover, size.width > 0, size.height > 0 else { return }
        let screen = popover.screen?.visibleFrame ?? popover.frame
        let frame = VitalsPanelPlacement.frame(for: size, beside: popover.frame, on: screen, gap: Design.Size.menuBarGap)
        guard frame != panel.frame else { return }
        panel.setFrame(frame, display: true)
        panel.invalidateShadow()
    }

    private func makePanel() -> VitalsPanel {
        let panel = VitalsPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        // The details draw their own rounded backdrop; the window itself is clear around it.
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        return panel
    }
}
