//
//  AreaDetailView.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// Everything found in one area, item by item, with the exact path or command behind each group.
struct AreaDetailView: View {
    @Environment(AppModel.self) private var model
    let area: Area

    var body: some View {
        let findings = model.findings(in: area)
        Group {
            if findings.isEmpty {
                ContentUnavailableView {
                    Label("Nothing to clean in \(area.title)", systemImage: "checkmark.circle")
                } description: {
                    Text(model.skipReason(for: area) ?? "The scan found nothing worth removing here.")
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        summary(findings)
                        ForEach(findings) { finding in
                            FindingCard(finding: finding)
                        }
                    }
                    .pageLayout()
                }
                .safeAreaInset(edge: .bottom) {
                    ActionBar {
                        ActionSummary(
                            title: "\(ByteFormat.string(model.selectedSize(in: area))) selected in \(area.title)",
                            detail: "What you tick here is part of the clean-up on the Overview."
                        )
                    } trailing: {
                        Button("Back to Overview") { model.select(.overview) }
                            .controlSize(.large)
                        Button("Review and Clean \(ByteFormat.string(model.selectedSize))") {
                            model.showingReview = true
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        .disabled(model.selectedSize == 0)
                    }
                }
            }
        }
        .navigationTitle(area.title)
        .navigationSubtitle(subtitle(findings))
    }

    private func subtitle(_ findings: [Finding]) -> String {
        guard !findings.isEmpty else { return "Nothing found" }
        let places = findings.count == 1 ? "1 place" : "\(findings.count) places"
        return "\(ByteFormat.string(model.foundSize(in: area))) in \(places)"
    }

    private func summary(_ findings: [Finding]) -> some View {
        let total = model.foundSize(in: area)
        return VStack(alignment: .leading, spacing: 16) {
            HeroFigure(
                caption: "Selected in \(area.title)",
                bytes: model.selectedSize(in: area),
                footnote: "of \(ByteFormat.string(total)) found",
                size: 44
            )
            if findings.count > 1 {
                DiskBar(
                    segments: findings.map { finding in
                        .init(id: finding.id, label: finding.title, bytes: finding.size, color: color(for: finding, in: findings))
                    },
                    total: total,
                    height: 14
                )
            }
        }
    }

    /// Findings of the same tier share a hue and step down in strength, so neighbours stay distinct.
    private func color(for finding: Finding, in findings: [Finding]) -> Color {
        let sameTier = findings.filter { $0.tier == finding.tier }
        let position = sameTier.firstIndex { $0.id == finding.id } ?? 0
        let strength = max(0.35, 1 - 0.25 * Double(position))
        switch finding.tier {
        case .safe: return Color.accentColor.opacity(strength)
        case .review: return Color.orange.opacity(strength)
        case .careful: return Color.primary.opacity(0.75 * strength)
        }
    }
}

private struct FindingCard: View {
    @Environment(AppModel.self) private var model
    let finding: Finding

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Toggle(sources: model.itemBindings(for: finding), isOn: \.self) {
                        Text(finding.title)
                            .font(.headline)
                    }
                    .toggleStyle(.checkbox)
                    TierBadge(tier: finding.tier)
                    Spacer(minLength: 12)
                    SizeLabel(bytes: finding.size)
                }
                Text(finding.explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text(finding.method.verb)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(finding.actionTarget)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 6))
                if let note = finding.note {
                    Text(note)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)

            ForEach(finding.items) { item in
                Divider()
                ItemRow(item: item, method: finding.method)
            }
        }
    }
}

private struct ItemRow: View {
    @Environment(AppModel.self) private var model
    let item: FindingItem
    let method: CleanMethod

    var body: some View {
        HStack(spacing: 12) {
            Toggle(isOn: model.binding(for: item)) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(item.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let hint = item.hint {
                        Text(hint)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(.leading, 6)
            }
            .toggleStyle(.checkbox)
            Spacer(minLength: 12)
            SizeLabel(bytes: item.size)
            if let first = item.paths.first {
                Button {
                    model.showInFinder(first)
                } label: {
                    Image(systemName: "magnifyingglass")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help("Show in Finder")
                .accessibilityLabel("Show \(item.title) in Finder")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
