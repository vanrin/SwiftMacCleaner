//
//  OverviewView.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// The scan results: everything found, grouped by how safe it is to remove.
struct OverviewView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.findings.isEmpty {
                ContentUnavailableView {
                    Label("Nothing to reclaim", systemImage: "checkmark.circle")
                } description: {
                    Text("The scan found nothing worth removing in the areas it looked at.")
                }
            } else {
                results
            }
        }
        .navigationTitle("Overview")
        .navigationSubtitle("\(model.disk.name), \(ByteFormat.string(model.disk.capacity))")
    }

    private var results: some View {
        let largest = model.findings.map(\.size).max() ?? 1
        return ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                summary
                ForEach(SafetyTier.allCases, id: \.self) { tier in
                    let group = model.findings.filter { $0.tier == tier }
                    if !group.isEmpty {
                        TierSection(tier: tier, findings: group, largest: largest)
                    }
                }
                if !model.unreadableFolders.isEmpty {
                    FullDiskAccessNote()
                }
            }
            .pageLayout()
        }
        .safeAreaInset(edge: .bottom) {
            ActionBar {
                ActionSummary(
                    title: "\(model.selectedFindingCount) of \(model.findings.count) selected",
                    detail: "Rebuildable items are deleted right away. Everything else goes to the Trash first."
                )
            } trailing: {
                Button("Review and Clean \(ByteFormat.string(model.selectedSize))") {
                    model.showingReview = true
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(model.selectedSize == 0)
            }
        }
    }

    private var summary: some View {
        let found = model.foundSize
        let selected = model.selectedSize
        let places = model.findings.count == 1 ? "1 place" : "\(model.findings.count) places"
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                HeroFigure(
                    caption: "Selected to reclaim",
                    bytes: selected,
                    footnote: "of \(ByteFormat.string(found)) found in \(places)"
                )
                Spacer(minLength: 24)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Free space after cleaning")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Text(ByteFormat.string(model.disk.free))
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text(ByteFormat.string(model.disk.free + selected))
                            .fontWeight(.bold)
                            .contentTransition(.numericText())
                            .animation(.default, value: selected)
                    }
                    .font(.system(.title3, design: .monospaced))
                }
            }
            DiskBar(
                segments: [
                    .init(id: "keep", label: "Keeping", bytes: max(0, model.disk.used - found), color: DiskBar.keepColor),
                    .init(id: "found", label: "Found, not selected", bytes: found - selected, color: DiskBar.foundColor),
                    .init(id: "selected", label: "Selected to clean", bytes: selected, color: DiskBar.selectedColor),
                    .init(id: "free", label: "Free now", bytes: model.disk.free, color: .clear, isRemainder: true),
                ],
                total: model.disk.capacity
            )
        }
    }
}

private struct TierSection: View {
    let tier: SafetyTier
    let findings: [Finding]
    let largest: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                TierBadge(tier: tier)
                Text(tier.headline)
                    .font(.headline)
                Text(tier.explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 12)
                SizeLabel(bytes: findings.reduce(0) { $0 + $1.size })
            }
            VStack(spacing: 0) {
                ForEach(findings) { finding in
                    Divider()
                    FindingRow(finding: finding, largest: largest)
                }
            }
        }
    }
}

private struct FindingRow: View {
    @Environment(AppModel.self) private var model
    let finding: Finding
    let largest: Int64

    var body: some View {
        let selected = model.selectedSize(in: finding)
        HStack(spacing: 14) {
            // Shows a dash when only some of the finding's items are ticked.
            Toggle(sources: model.itemBindings(for: finding), isOn: \.self) {
                Text(finding.title)
            }
            .toggleStyle(.checkbox)
            .labelsHidden()

            Image(systemName: finding.area.symbol)
                .frame(width: 22)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(finding.title)
                    .fontWeight(.semibold)
                Text(finding.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 5) {
                SizeLabel(bytes: finding.size)
                Capsule()
                    .fill(.quaternary)
                    .frame(width: 96, height: 4)
                    .overlay(alignment: .trailing) {
                        Capsule()
                            .fill(selected > 0 ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                            .frame(width: max(4, 96 * CGFloat(finding.size) / CGFloat(max(largest, 1))))
                    }
                    .accessibilityHidden(true)
            }
            Button {
                model.select(.area(finding.area))
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("Show what is inside")
            .accessibilityLabel("Details for \(finding.title)")
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 4)
    }
}
