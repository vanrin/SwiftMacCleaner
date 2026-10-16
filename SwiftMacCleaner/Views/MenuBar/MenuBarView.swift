//
//  MenuBarView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The popover under the menu bar item: how full the disk is, what the processor, memory and battery
/// are doing, what the last scan found, one button.
struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    private let theme = MenuBarSurface.theme

    var body: some View {
        let disk = model.disk
        VStack(alignment: .leading, spacing: Design.Spacing.large) {
            HStack {
                Text(disk.name)
                    .font(.headline)
                Spacer()
                Text(ByteFormat.string(disk.capacity))
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.quiet)
            }

            HStack(spacing: Design.Spacing.medium) {
                Text("\(ByteFormat.string(disk.free)) free")
                    .font(.title)
                    .bold()
                    .monospacedDigit()
                if disk.isLow {
                    Badge(text: "Running low", style: .waits)
                }
            }

            UsageBar(segments: segments, total: disk.capacity)
                .accessibilityHidden(false)
                .accessibilityLabel("Disk usage")

            VitalTiles()

            MenuBarOffer(open: openMain)

            if model.hasFindings {
                VStack(alignment: .leading, spacing: Design.Spacing.small) {
                    Text("Largest areas")
                        .font(.callout)
                        .bold()
                        .foregroundStyle(.quiet)
                    ForEach(model.largestAreas(3), id: \.area) { entry in
                        HStack(spacing: Design.Spacing.medium) {
                            FeatureIcon(Image(entry.area.glyph), theme: entry.area.theme, size: Design.Size.listGlyph)
                            Text(entry.area.title)
                            Spacer()
                            SizeLabel(bytes: entry.size)
                        }
                    }
                }
            }

            HStack {
                Text(footer)
                    .font(.callout)
                    .foregroundStyle(.quiet)
                Spacer()
                Button("Open SwiftMacCleaner", action: openMain)
                    .buttonStyle(.plain)
                    .bold()
                    .foregroundStyle(.tint)
            }
        }
        .menuBarSurface()
        .background {
            // In the demo the details are drawn in the window beside the popover, not in a panel of their own.
            VitalsPanelAnchor(model: model, detail: model.showsMenuBarDemo ? nil : model.vitals.detail, openMain: openMain)
        }
        .onAppear(perform: opened)
        .onDisappear(perform: model.vitals.menuClosed)
    }

    private func opened() {
        model.backgroundTick()
        model.vitals.menuOpened()
    }

    /// The disk split into what stays, what was found and is not part of the Smart selection, and
    /// what is.
    private var segments: [UsageSegment] {
        let found = model.foundSize
        let smart = model.smartSize
        return [
            UsageSegment(id: "keep", label: "Keeping", bytes: max(0, model.disk.used - found), color: Design.Surface.keeping),
            UsageSegment(id: "found", label: "Also found", bytes: max(0, found - smart), color: theme.faintAccent),
            UsageSegment(id: "selected", label: "Selected", bytes: smart, color: theme.accent),
        ]
    }

    private var footer: String {
        guard let date = model.settings.lastScanDate else { return "Never scanned" }
        return "Scanned \(date.formatted(.relative(presentation: .named, unitsStyle: .wide)))"
    }

    private func openMain() {
        openWindow(id: "main")
        // Opened at login, the app is hidden until it is asked for.
        NSApp.unhide(nil)
        NSApp.activate()
        // The menu has done its part. Left open it would hang over the window it just brought forward,
        // with the details beside it.
        dismiss()
    }
}
