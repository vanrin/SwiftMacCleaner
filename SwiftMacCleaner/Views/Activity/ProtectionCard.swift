//
//  ProtectionCard.swift
//  SwiftMacCleaner
//

import SwiftUI

/// How the Protection check last found this Mac: how many of its settings are as they should be, and
/// which are worth a look. The check only reads, so it can be run from here without leaving the page.
struct ProtectionCard: View {
    @Environment(AppModel.self) private var model

    static let info = "The macOS settings the Protection check reads, as they stood at its last check: FileVault, Screen Lock, Gatekeeper, System Integrity Protection, the malware definitions, automatic updates, the firewall and remote access. The app never changes them; each one is changed in System Settings."

    var body: some View {
        let protection = model.protection
        let snapshot = protection.snapshot ?? model.activity.protection
        ActivityCard(title: "Protection", info: Self.info) {
            if protection.phase == .scanning {
                ActivityFigure(value: "Checking…", isEmpty: true)
                ProgressView()
                    .controlSize(.small)
                    .padding(.top, Design.Spacing.small)
                Spacer(minLength: 0)
            } else if let snapshot {
                ActivityFigure(value: "\(snapshot.inPlace) of \(snapshot.settings.count)", unit: "settings in order")
                HStack(spacing: Design.Spacing.tight) {
                    ForEach(Array(snapshot.settings.enumerated()), id: \.offset) { _, setting in
                        segment(setting.state)
                    }
                }
                .frame(height: 10)
                .padding(.top, Design.Spacing.tight)
                .accessibilityHidden(true)
                VStack(spacing: Design.Spacing.tight) {
                    ForEach(snapshot.toCheck.prefix(3), id: \.name) { setting in
                        HStack(spacing: Design.Spacing.small + 1) {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundStyle(Design.Signal.review)
                            Text(setting.name)
                                .bold()
                                .lineLimit(1)
                                .layoutPriority(1)
                            Spacer(minLength: Design.Spacing.small)
                            Text(setting.status)
                                .foregroundStyle(.quiet)
                                .lineLimit(1)
                                .help(setting.status)
                        }
                        .font(.callout)
                        .accessibilityElement(children: .combine)
                    }
                    if snapshot.toCheck.isEmpty {
                        Label("Nothing to look at", systemImage: "checkmark.circle")
                            .font(.callout)
                            .foregroundStyle(Design.Signal.safe)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, Design.Spacing.small)
                Spacer(minLength: 0)
                HStack(spacing: Design.Spacing.small) {
                    Text("Checked \(snapshot.date.formatted(.dateTime.day().month(.wide)))")
                        .font(.callout)
                        .foregroundStyle(.quiet)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button("Open Protection", action: openProtection)
                        .buttonStyle(.compactPill)
                }
            } else {
                ActivityFigure(value: "Not checked", isEmpty: true)
                HStack(spacing: Design.Spacing.tight) {
                    ForEach(0..<ProtectionCheck.allCases.count, id: \.self) { _ in
                        Capsule().fill(Design.Surface.track)
                    }
                }
                .frame(height: 10)
                .padding(.top, Design.Spacing.tight)
                .accessibilityHidden(true)
                Text("The check reads \(ProtectionCheck.allCases.count) macOS settings, from FileVault to the firewall, and changes none of them.")
                    .font(.callout)
                    .foregroundStyle(.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Design.Spacing.small)
                Spacer(minLength: 0)
                Button("Check Now", action: check)
                    .buttonStyle(.compactPill)
            }
        }
    }

    /// One setting: solid when it is in place, outlined in amber when it is worth a look, empty otherwise.
    private func segment(_ state: ProtectionSnapshot.Setting.State) -> some View {
        Capsule()
            .fill(state == .inPlace ? AnyShapeStyle(Theme.green.lens) : AnyShapeStyle(Design.Surface.well))
            .strokeBorder(state == .needsLook ? Theme.amber.lens : .clear, lineWidth: 1.5)
    }

    private func check() {
        model.protection.startScan()
    }

    private func openProtection() {
        model.select(.protection)
    }
}
