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
        let smart = model.smartSize
        let isBusy = model.overviewPhase == .scanning || model.overviewPhase == .running
            || model.cleanUps.contains(where: \.isBusy)
        GlassPanel(cornerRadius: Design.Radius.tile) {
            VStack(alignment: .leading, spacing: Design.Spacing.medium) {
                TitledDetail(title: title(smart: smart), detail: detail(smart: smart), detailLineLimit: nil)
                if !isBusy {
                    Button(action: act) {
                        Text(smart > 0 ? "Clean \(ByteFormat.string(smart))" : "Scan \(model.disk.name)")
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
        if model.smartSize > 0 {
            model.cleanSmart()
        } else {
            model.startScan()
        }
    }

    private func title(smart: Int64) -> String {
        switch model.overviewPhase {
        case .scanning: "Scanning"
        case .running: "Cleaning"
        default:
            if smart > 0 {
                "\(ByteFormat.string(smart)) ready to clean"
            } else if !model.hasFindings {
                model.settings.lastScanDate == nil ? "Not scanned yet" : "Nothing to clean"
            } else {
                "Nothing selected to clean"
            }
        }
    }

    private func detail(smart: Int64) -> String {
        switch model.overviewPhase {
        case .scanning: "\(model.overviewParts.count - model.scanningParts.count) of \(model.overviewParts.count) parts done"
        case .running: model.runProgress.status
        default:
            if smart > 0 {
                "\(ByteFormat.string(model.foundSize)) found in the last scan. The Smart selection is ticked, and you confirm before anything is removed."
            } else if !model.hasFindings {
                "A scan shows everything that can go and ticks the part worth cleaning now."
            } else {
                "\(ByteFormat.string(model.foundSize)) found, none of it in the Smart selection. Open the app to choose what goes."
            }
        }
    }
}
