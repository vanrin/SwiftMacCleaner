//
//  AreaDetailView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// Everything found in one area, item by item, with the exact path or command behind each group.
struct AreaDetailView: View {
    @Environment(AppModel.self) private var model
    let area: Area

    var body: some View {
        let findings = model.findings(in: area)
        let protected = model.protected(in: area)
        let active = model.activeChecks()
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Design.Spacing.xLarge) {
                if findings.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing to clean in \(area.title)", systemImage: "checkmark.circle")
                    } description: {
                        Text(model.skipReason(for: area) ?? "The scan found nothing worth removing here.")
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
            .pageLayout()
        }
        .orbAction {
            if !findings.isEmpty {
                CleanButton()
            }
        }
    }

    private func detail(_ findings: [Finding]) -> String {
        let places = findings.count == 1 ? "1 place" : "\(findings.count) places"
        var text = "\(ByteFormat.string(model.foundSize(in: area))) found in \(places), \(ByteFormat.string(model.selectedSize(in: area))) of it selected."
        if findings.allSatisfy({ $0.tier != .safe }) {
            text += " Nothing here is ticked for you: each row is a guess backed by the evidence shown, and you decide."
        }
        if findings.allSatisfy({ $0.method == .trash }) {
            text += " These go to the Trash and can be put back."
        }
        return text
    }
}
