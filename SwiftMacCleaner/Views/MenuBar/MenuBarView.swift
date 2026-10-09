//
//  MenuBarView.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The popover under the menu bar item: how full the disk is, what the last scan found, one button.
struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    private let theme = Theme.violet

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
                    .foregroundStyle(.secondary)
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

            MenuBarOffer(open: openMain)

            if !model.findings.isEmpty {
                VStack(alignment: .leading, spacing: Design.Spacing.small) {
                    Text("Largest areas")
                        .font(.callout)
                        .bold()
                        .foregroundStyle(.secondary)
                    ForEach(model.largestAreas(3), id: \.area) { entry in
                        HStack(spacing: Design.Spacing.medium) {
                            FeatureIcon(Image(entry.area.glyph), theme: entry.area.theme, size: Design.Size.sidebarGlyph)
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
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Open SwiftMacCleaner", action: openMain)
                    .buttonStyle(.plain)
                    .bold()
                    .foregroundStyle(.tint)
            }
        }
        .padding(Design.Spacing.large)
        .frame(width: Design.Size.menuBarWidth)
        .background {
            ThemeBackdrop(theme: theme)
        }
        .environment(\.theme, theme)
        .tint(theme.accent)
        // A menu bar window keeps the system's appearance whatever is preferred, so the dark scheme is set
        // on the content itself. Otherwise the text is black on the backdrop while the Mac is in Light mode.
        .environment(\.colorScheme, .dark)
        .typesettingLanguage(Design.language)
        .onAppear(perform: model.backgroundTick)
    }

    /// The disk split into what stays, what needs a decision, and what can go safely.
    private var segments: [UsageSegment] {
        let found = model.foundSize
        let safe = model.safeSize
        return [
            UsageSegment(id: "keep", label: "Keeping", bytes: max(0, model.disk.used - found), color: Design.Surface.keeping),
            UsageSegment(id: "review", label: "Needs your call", bytes: max(0, found - safe), color: theme.faintAccent),
            UsageSegment(id: "safe", label: "Safe to remove", bytes: safe, color: theme.accent),
        ]
    }

    private var footer: String {
        guard let date = model.settings.lastScanDate else { return "Never scanned" }
        return "Scanned \(date.formatted(.relative(presentation: .named, unitsStyle: .wide)))"
    }

    private func openMain() {
        openWindow(id: "main")
        NSApp.activate()
    }
}
