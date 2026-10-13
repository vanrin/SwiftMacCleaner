//
//  AreaFindings.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Everything found in one area, item by item, with the exact path or command behind each group. It is
/// the body of an area's page under the overview, and of an area's pane in the System Clean Up manager.
struct AreaFindings: View {
    @Environment(CleanUpModel.self) private var cleanUp
    let area: Area
    /// Set when the list sits beside the manager's column: the heading is the pane's, with a way to
    /// tick or untick the whole area.
    var isPane = false

    var body: some View {
        let findings = cleanUp.findings(in: area)
        let protected = cleanUp.protected(in: area)
        let active = cleanUp.activeChecks()
        LazyVStack(alignment: .leading, spacing: isPane ? Design.Spacing.large : Design.Spacing.xLarge) {
            if findings.isEmpty {
                ContentUnavailableView {
                    Label("Nothing to clean in \(area.title)", systemImage: "checkmark.circle")
                } description: {
                    Text(cleanUp.skipReason(for: area) ?? "The scan found nothing worth removing here.")
                }
            } else if isPane {
                PaneHeading(title: area.title, detail: detail(findings)) {
                    Spacer(minLength: 0)
                    PresetControl(preset: cleanUp.preset(in: area), select: select)
                }
            } else {
                PageHeading(title: area.title, detail: detail(findings))
            }
            ForEach(findings) { finding in
                FindingCard(finding: finding, active: active[finding.id])
            }
            if !protected.isEmpty {
                ProtectedList(title: "Also found, left alone",
                              subtitle: "Why each one stays, so the number adds up.",
                              items: protected)
            }
        }
    }

    private func detail(_ findings: [Finding]) -> String {
        let places = findings.count == 1 ? "1 place" : "\(findings.count) places"
        var text = "\(ByteFormat.string(cleanUp.foundSize(in: area))) found in \(places), \(ByteFormat.string(cleanUp.selectedSize(in: area))) of it selected."
        if findings.smartSelection(cleanUp.settings.smartKinds).isEmpty {
            text += " Smart selection ticks nothing here: each row is a guess backed by the evidence shown, and you decide."
        }
        if findings.allSatisfy({ $0.method == .trash }) {
            text += " These go to the Trash and can be put back."
        }
        return text
    }

    private func select(_ preset: SelectionPreset) {
        cleanUp.select(preset, in: area)
    }
}
