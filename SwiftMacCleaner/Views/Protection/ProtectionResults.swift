//
//  ProtectionResults.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What the check found: a sentence that sums it up, then every setting with how it stands. What needs
/// a look comes first, each with a way to where it is changed.
struct ProtectionResults: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let protection = model.protection
        let toLookAt = protection.toLookAt
        ScrollView {
            VStack(spacing: Design.Spacing.section) {
                VStack(spacing: Design.Spacing.large) {
                    Text(headline(toLookAt.count))
                        .font(Design.Typeface.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text(detail(protection))
                        .font(Design.Typeface.tileBody)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Design.Spacing.medium)

                section("To look at", "Off, or weaker than it could be. Each is yours to change in System Settings.", toLookAt)
                section("Could not be read", "macOS gave no answer for these, so they are neither counted nor cleared.", protection.unread)
                section("Left as you chose", "Off, and not counted, because you said to leave them this way.", protection.accepted)
                section("In place", nil, protection.inPlace)
            }
            .pageLayout()
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ detail: String?, _ findings: [ProtectionFinding]) -> some View {
        if !findings.isEmpty {
            VStack(alignment: .leading, spacing: Design.Spacing.medium) {
                SectionHeading(title: title, detail: detail)
                GlassPanel {
                    ForEach(findings) { finding in
                        ProtectionRow(finding: finding, showsDivider: finding.id != findings.first?.id)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func headline(_ count: Int) -> String {
        switch count {
        case 0: "This Mac's defences are in place"
        case 1: "1 setting is worth a look"
        default: "\(count) settings are worth a look"
        }
    }

    private func detail(_ protection: ProtectionModel) -> String {
        let total = protection.findings.count
        let inPlace = protection.inPlace.count
        var text = "\(inPlace) of \(total) checks are as Apple ships them or stricter."
        if !protection.accepted.isEmpty {
            let count = protection.accepted.count
            text += " \(count) \(count == 1 ? "is" : "are") off because you chose so."
        }
        return text + " Nothing is changed from here."
    }
}
