//
//  AppsReviewSheet.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The last look before apps or leftovers are moved to the Trash: what goes, what waits, and what macOS will ask.
struct AppsReviewSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let apps = model.apps
        let plan = apps.plan
        let blocked = apps.blockedSteps(in: plan)
        let total = plan.steps.filter { blocked[$0.id] == nil }.reduce(Int64(0)) { $0 + $1.size }
        let verb = apps.removesLeftovers ? "Remove" : "Uninstall"
        let systemFiles = apps.selectedSystemFileCount
        VStack(alignment: .leading, spacing: Design.Spacing.xLarge) {
            VStack(alignment: .leading, spacing: Design.Spacing.tight) {
                Text(title(apps, plan: plan))
                    .font(.title)
                    .bold()
                Text("\(ByteFormat.string(total)) goes to the Trash. Nothing is deleted, and \(systemFiles == 0 ? "it can all" : "all but the files from /Library can") be put back from the next screen.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            GlassPanel {
                ScrollView {
                    VStack(spacing: 0) {
                        if apps.removesLeftovers {
                            ForEach(plan.steps) { step in
                                ReviewStepRow(step: step, isBlocked: false, showsDivider: step.id != plan.steps.first?.id)
                            }
                        } else {
                            let chosen = apps.apps(in: plan)
                            ForEach(chosen) { app in
                                if let step = plan.steps.first(where: { $0.id == Uninstaller.stepID(for: app) }) {
                                    AppsReviewRow(app: app, step: step, showsDivider: app.id != chosen.first?.id)
                                }
                            }
                        }
                    }
                }
                .frame(minHeight: 120, maxHeight: 300)
                .scrollBounceBehavior(.basedOnSize)
            }

            VStack(alignment: .leading, spacing: Design.Spacing.small) {
                Text("Before you \(verb.lowercased())")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                ForEach(checks(apps, plan: plan, blockedCount: blocked.count), id: \.text) { check in
                    Label {
                        Text(check.text)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: check.isWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(check.isWarning ? AnyShapeStyle(Design.Signal.warning) : AnyShapeStyle(.tint))
                    }
                    .font(.callout)
                }
            }

            HStack(spacing: Design.Spacing.medium) {
                Spacer()
                Button("Cancel", role: .cancel, action: cancel)
                    .buttonStyle(.pill)
                    .keyboardShortcut(.cancelAction)
                Button("\(verb) \(ByteFormat.string(total))", action: apps.remove)
                    .buttonStyle(.primaryPill)
                    .disabled(plan.steps.count == blocked.count)
            }
        }
        .padding(Design.Spacing.xLarge)
        .frame(width: Design.Size.sheetWidth)
        .presentationBackground {
            ThemeBackdrop(theme: theme)
        }
        .preferredColorScheme(.dark)
    }

    private func cancel() {
        dismiss()
    }

    private func title(_ apps: AppsModel, plan: CleanPlan) -> String {
        if apps.removesLeftovers {
            let count = apps.selectedLeftoverCount
            return "Remove \(count == 1 ? "1 leftover" : "\(count) leftovers")?"
        }
        let count = apps.selectedAppCount
        if count == 0 { return "Remove the ticked files?" }
        return "Uninstall \(count == 1 ? "1 app" : "\(count) apps")?"
    }

    private func checks(_ apps: AppsModel, plan: CleanPlan, blockedCount: Int) -> [(text: String, isWarning: Bool)] {
        var checks: [(text: String, isWarning: Bool)] = []
        if apps.removesLeftovers {
            checks.append(("Every path is checked again just before it is moved. Anything that changed since the scan is left alone and listed on the receipt.", false))
            return checks
        }
        checks.append(("Each app is moved first. If macOS does not let it go, the files it keeps stay where they are.", false))
        if blockedCount > 0 {
            checks.append(("\(blockedCount == 1 ? "1 app is" : "\(blockedCount) apps are") open and will be left alone. Quit \(blockedCount == 1 ? "it" : "them") above to include \(blockedCount == 1 ? "it" : "them"). Nothing is quit for you.", true))
        }
        if apps.needsFinder {
            checks.append(("Apps installed by the App Store or by a package belong to the system. Finder moves those, and macOS asks for your password.", true))
        }
        let systemFiles = apps.selectedSystemFileCount
        if systemFiles > 0 {
            checks.append(("\(systemFiles == 1 ? "1 file is" : "\(systemFiles) files are") in /Library and \(systemFiles == 1 ? "belongs" : "belong") to the system: background items and the helpers they run. With your password \(systemFiles == 1 ? "it is" : "they are") stopped and moved to a folder of \(systemFiles == 1 ? "its" : "their") own in the Trash. Put Back does not return \(systemFiles == 1 ? "it" : "them").", true))
        }
        checks.append(("macOS guards app bundles. Where it does not let this app move one, Finder is asked to, and macOS may ask you once to allow that.", false))
        if plan.steps.contains(where: { !$0.requiresFirst }) {
            checks.append(("For some apps only files are ticked, not the app. Those apps stay and start as if newly installed.", true))
        }
        return checks
    }
}
