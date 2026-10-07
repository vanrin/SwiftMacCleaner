//
//  HomeView.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// What the app shows before a scan: how full the disk is, and what a scan will look at.
struct HomeView: View {
    @Environment(AppModel.self) private var model

    private let columns = [GridItem(.flexible(), spacing: 32), GridItem(.flexible())]

    static let neverTouched = [
        "Your source files", "Git repositories", "iCloud Drive and cloud folders", "Files not downloaded from iCloud",
        "Photos, Mail, Messages libraries", "Keychains and credentials", "Docker volumes",
        "Other disks and network volumes", "The current Xcode and your default toolchains",
        "Anything changed after the scan", "Your Never Suggest list",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                diskStatus
                if model.isSandboxed { sandboxNote }
                if !model.hasFullDiskAccess { fullDiskAccessNote }
                if let pending = model.putBackPending { PutBackCard(manifest: pending) }
                if let message = model.putBackMessage { PutBackMessage(text: message) }
                areaPicker
                neverTouched
            }
            .pageLayout()
        }
        .safeAreaInset(edge: .bottom) {
            ActionBar {
                ActionSummary(
                    title: "\(model.enabledAreas.count) of \(Area.allCases.count) areas selected",
                    detail: "About a minute. Nothing is removed until you confirm, and nothing here needs your password unless a step says so."
                )
            } trailing: {
                Button("Quick Clean, Safe only") { model.quickClean() }
                    .controlSize(.large)
                    .help("Scan everything, keep only what rebuilds itself ticked, then show the confirmation")
                    .disabled(model.enabledAreas.isEmpty)
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
        let disk = model.disk
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 10) {
                    Text("Free space")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if disk.isLow {
                        Badge(text: "Running low", style: .waits)
                    }
                }
                Text(ByteFormat.string(disk.free))
                    .font(.system(size: 56, weight: .bold))
                    .monospacedDigit()
                Text(footnote(for: disk))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            DiskBar(
                segments: segments(for: disk),
                total: disk.capacity
            )
        }
    }

    private func footnote(for disk: DiskInfo) -> String {
        let base = "of \(ByteFormat.string(disk.capacity)) on \(disk.name)."
        guard disk.purgeable > 0 else { return base }
        return base + " Another \(ByteFormat.string(disk.purgeable)) is purgeable: files macOS frees on its own schedule."
    }

    private func segments(for disk: DiskInfo) -> [DiskBar.Segment] {
        var segments = [DiskBar.Segment(id: "used", label: "Used", bytes: disk.used, color: DiskBar.keepColor)]
        if disk.purgeable > 0 {
            segments.append(.init(id: "purgeable", label: "Purgeable", bytes: disk.purgeable, color: DiskBar.purgeableColor, pattern: true))
        }
        segments.append(.init(id: "free", label: "Free", bytes: disk.free, color: .clear, isRemainder: true))
        return segments
    }

    private var areaPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("What the scan looks at")
                    .font(.headline)
                Text("Untick anything you want left alone. Tools that are not installed are skipped. Scanning only measures.")
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
                                    HStack(spacing: 8) {
                                        Text(area.title)
                                            .fontWeight(.semibold)
                                        if area.isNew {
                                            Badge(text: "New", style: .new)
                                        }
                                    }
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

    private var neverTouched: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield")
                        .foregroundStyle(.tint)
                    Text("Never touched, whatever you tick")
                        .fontWeight(.semibold)
                }
                FlowLayout(spacing: 8) {
                    ForEach(Self.neverTouched, id: \.self) { chip in
                        Text(chip)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 6))
                    }
                }
            }
            .padding(14)
        }
    }

    private var fullDiskAccessNote: some View {
        Card {
            HStack(spacing: 12) {
                Image(systemName: "lock")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Full Disk Access is off")
                        .fontWeight(.semibold)
                    Text("Downloads, the Trash, Mail and app containers stay private without it, so those areas are skipped. Everything else is scanned either way. The app checks again each time it opens.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Button("Open Privacy Settings") { model.openFullDiskAccessSettings() }
            }
            .padding(14)
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

/// Lays chips out left to right, wrapping to a new line when a row is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 600
        return place(in: width, subviews: subviews, assign: false)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        _ = place(in: bounds.width, subviews: subviews, assign: true, origin: bounds.origin)
    }

    private func place(in width: CGFloat, subviews: Subviews, assign: Bool, origin: CGPoint = .zero) -> CGSize {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            if assign {
                subview.place(at: CGPoint(x: origin.x + x, y: origin.y + y), proposal: ProposedViewSize(size))
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return CGSize(width: maxX, height: y + rowHeight)
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
                .frame(width: 190, alignment: .leading)
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
