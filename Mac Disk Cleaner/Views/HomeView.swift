//
//  HomeView.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// What the app shows before a scan: how full the disk is, and what a scan will look at.
struct HomeView: View {
    @Environment(AppModel.self) private var model

    private let columns = [GridItem(.flexible(), spacing: 32), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                diskStatus
                if model.isSandboxed { sandboxNote }
                areaPicker
            }
            .pageLayout()
        }
        .safeAreaInset(edge: .bottom) {
            ActionBar {
                ActionSummary(
                    title: "\(model.enabledAreas.count) of \(Area.allCases.count) areas selected",
                    detail: "About a minute. Scanning only measures, and nothing is removed until you confirm."
                )
            } trailing: {
                Button("Scan \(model.disk.name)") { model.startScan() }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.enabledAreas.isEmpty)
            }
        }
        .navigationTitle("Overview")
        .navigationSubtitle("\(model.disk.name), \(ByteFormat.string(model.disk.capacity))")
    }

    private var diskStatus: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 10) {
                    Text("Free space")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if model.disk.isLow {
                        Text("Running low")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .foregroundStyle(Color.orange.mix(with: .primary, by: 0.45))
                            .background(Color.orange.opacity(0.2), in: .rect(cornerRadius: 5))
                    }
                }
                Text(ByteFormat.string(model.disk.free))
                    .font(.system(size: 56, weight: .bold))
                    .monospacedDigit()
                Text("of \(ByteFormat.string(model.disk.capacity)) on \(model.disk.name)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            DiskBar(
                segments: [
                    .init(id: "used", label: "Used", bytes: model.disk.used, color: DiskBar.keepColor),
                    .init(id: "free", label: "Free", bytes: model.disk.free, color: .clear, isRemainder: true),
                ],
                total: model.disk.capacity
            )
        }
    }

    private var areaPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("What the scan looks at")
                    .font(.headline)
                Text("Untick anything you want left alone. Tools that are not installed are skipped.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
                ForEach(Area.allCases) { area in
                    VStack(spacing: 0) {
                        Divider()
                        Toggle(isOn: model.binding(for: area)) {
                            HStack(spacing: 12) {
                                Image(systemName: area.symbol)
                                    .frame(width: 22)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(area.title)
                                        .fontWeight(.semibold)
                                    Text(area.summary)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.leading, 6)
                        }
                        .toggleStyle(.checkbox)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    }
                }
            }
        }
    }

    private var sandboxNote: some View {
        Card {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text("App Sandbox is on")
                        .fontWeight(.semibold)
                    Text("A sandboxed app can only see its own container, so a scan will find almost nothing. Remove the App Sandbox capability from the target in Xcode to scan your real folders.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
        }
    }
}

/// Progress while the areas are being measured.
struct ScanningView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let areas = model.scannedAreas
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 14) {
                    HeroFigure(
                        caption: "Found so far",
                        bytes: model.foundSize,
                        footnote: "Scanning only measures. Nothing is removed until you confirm."
                    )
                    ProgressView(value: Double(model.finishedAreaCount), total: Double(max(areas.count, 1)))
                    Text("\(model.finishedAreaCount) of \(areas.count) areas done")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Card {
                    ForEach(areas) { area in
                        if area != areas.first { Divider() }
                        row(for: area)
                    }
                }
            }
            .pageLayout(maxWidth: 780)
        }
        .navigationTitle("Scanning")
        .navigationSubtitle("\(model.disk.name), \(ByteFormat.string(model.disk.capacity))")
    }

    private func row(for area: Area) -> some View {
        let state = model.areaState(for: area)
        return HStack(spacing: 12) {
            statusIcon(for: state)
                .frame(width: 18)
            Text(area.title)
                .fontWeight(.semibold)
                .frame(width: 170, alignment: .leading)
            Text(detail(for: area, state: state))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 12)
            switch state {
            case .finished:
                SizeLabel(bytes: model.foundSize(in: area))
            case .scanning:
                Text("Scanning").font(.caption.weight(.semibold))
            case .queued:
                Text("Queued").font(.caption).foregroundStyle(.secondary)
            case .skipped:
                Text("Skipped").font(.caption).foregroundStyle(.secondary)
            case .idle:
                EmptyView()
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
    }

    @ViewBuilder
    private func statusIcon(for state: AppModel.AreaState) -> some View {
        switch state {
        case .finished:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
        case .scanning:
            ProgressView().controlSize(.small)
        case .skipped:
            Image(systemName: "minus.circle").foregroundStyle(.secondary)
        case .queued, .idle:
            Image(systemName: "circle").foregroundStyle(.tertiary)
        }
    }

    private func detail(for area: Area, state: AppModel.AreaState) -> String {
        if case .skipped(let reason) = state { return reason }
        return area.summary
    }
}
