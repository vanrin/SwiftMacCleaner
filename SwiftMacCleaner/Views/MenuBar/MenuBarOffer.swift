//
//  MenuBarOffer.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The panel in the menu bar popover that says what can be done right now, with one button to do it.
struct MenuBarOffer: View {
    @Environment(AppModel.self) private var model
    /// Brings the main window forward, where the scan or the confirmation appears.
    let open: () -> Void

    var body: some View {
        let safe = model.safeSize
        let isBusy = model.phase == .scanning || model.phase == .cleaning
        GlassPanel(cornerRadius: Design.Radius.tile) {
            VStack(alignment: .leading, spacing: Design.Spacing.medium) {
                TitledDetail(title: title(safe: safe), detail: detail(safe: safe), detailLineLimit: nil)
                if !isBusy {
                    Button(action: act) {
                        Text(safe > 0 ? "Clean \(ByteFormat.string(safe))" : "Scan \(model.disk.name)")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primaryPill)
                }
            }
            .padding(Design.Spacing.medium)
        }
    }

    private func act() {
        open()
        if model.safeSize > 0 {
            model.cleanSafe()
        } else {
            model.startScan()
        }
    }

    private func title(safe: Int64) -> String {
        switch model.phase {
        case .scanning: "Scanning"
        case .cleaning: "Cleaning"
        default:
            if safe > 0 {
                "\(ByteFormat.string(safe)) can go safely"
            } else if model.findings.isEmpty {
                model.settings.lastScanDate == nil ? "Not scanned yet" : "Nothing safe to remove"
            } else {
                "Nothing safe left to remove"
            }
        }
    }

    private func detail(safe: Int64) -> String {
        switch model.phase {
        case .scanning: "\(model.finishedAreaCount) of \(model.scannedAreas.count) areas done"
        case .cleaning: model.cleanProgress.status
        default:
            if safe > 0 {
                "Build output and caches that rebuild themselves. You confirm before anything is removed."
            } else if model.findings.isEmpty {
                "A scan only measures. Nothing is removed until you confirm."
            } else {
                "\(ByteFormat.string(model.foundSize)) more needs your call in the app."
            }
        }
    }
}
