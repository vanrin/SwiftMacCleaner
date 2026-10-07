//
//  MenuBarView.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// The popover under the menu bar item: how full the disk is, what the last scan found, one button.
struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(model.disk.name)
                    .font(.callout.weight(.semibold))
                Spacer()
                Text(ByteFormat.string(model.disk.capacity))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Text("\(ByteFormat.string(model.disk.free)) free")
                    .font(.system(size: 28, weight: .bold))
                    .monospacedDigit()
                if model.disk.isLow {
                    Badge(text: "Running low", style: .waits)
                }
            }

            bar

            offer

            if !model.findings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Largest areas")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(model.largestAreas(3), id: \.area) { entry in
                        HStack {
                            Text(entry.area.title)
                            Spacer()
                            Text(ByteFormat.string(entry.size))
                                .font(.system(.caption, design: .monospaced))
                        }
                        .font(.callout)
                        .frame(minHeight: 28)
                        Divider()
                    }
                }
            }

            HStack {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Open Mac Disk Cleaner") { openMain() }
                    .buttonStyle(.link)
                    .font(.callout.weight(.semibold))
            }
        }
        .padding(16)
        .frame(width: 360)
        .onAppear { model.backgroundTick() }
    }

    private var bar: some View {
        let found = model.foundSize
        let safe = model.safeSize
        let review = max(0, found - safe)
        return GeometryReader { geometry in
            let total = CGFloat(max(model.disk.capacity, 1))
            HStack(spacing: 1) {
                Rectangle().fill(DiskBar.keepColor)
                    .frame(width: geometry.size.width * CGFloat(max(0, model.disk.used - found)) / total)
                Rectangle().fill(DiskBar.foundColor)
                    .frame(width: geometry.size.width * CGFloat(review) / total)
                Rectangle().fill(DiskBar.selectedColor)
                    .frame(width: geometry.size.width * CGFloat(safe) / total)
                Spacer(minLength: 0)
            }
        }
        .frame(height: 12)
        .background(.quaternary)
        .clipShape(.rect(cornerRadius: 6))
        .accessibilityLabel("Disk usage")
    }

    @ViewBuilder
    private var offer: some View {
        let safe = model.safeSize
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                switch model.phase {
                case .scanning:
                    Text("Scanning")
                        .fontWeight(.semibold)
                    Text("\(model.finishedAreaCount) of \(model.scannedAreas.count) areas done")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .cleaning:
                    Text("Cleaning")
                        .fontWeight(.semibold)
                    Text(model.cleanProgress.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                default:
                    if safe > 0 {
                        Text("\(ByteFormat.string(safe)) can go safely")
                            .fontWeight(.semibold)
                        Text("Build output and caches that rebuild themselves. You confirm before anything is removed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if model.findings.isEmpty {
                        Text(model.settings.lastScanDate == nil ? "Not scanned yet" : "Nothing safe to remove")
                            .fontWeight(.semibold)
                        Text("A scan only measures. Nothing is removed until you confirm.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Nothing safe left to remove")
                            .fontWeight(.semibold)
                        Text("\(ByteFormat.string(model.foundSize)) more needs your call in the app.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if model.phase != .scanning, model.phase != .cleaning {
                Button(safe > 0 ? "Clean \(ByteFormat.string(safe))" : "Scan \(model.disk.name)") {
                    openMain()
                    if safe > 0 { model.cleanSafe() } else { model.startScan() }
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 10))
    }

    private var footer: String {
        guard let date = model.settings.lastScanDate else { return "Never scanned" }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .full
        return "Scanned \(relative.localizedString(for: date, relativeTo: Date()))"
    }

    private func openMain() {
        openWindow(id: "main")
        NSApp.activate()
    }
}
