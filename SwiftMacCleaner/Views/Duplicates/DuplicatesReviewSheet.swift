//
//  DuplicatesReviewSheet.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The last look before duplicates are moved to the Trash: how many of each kind, what that gives
/// back, and what is checked once more on the way.
struct DuplicatesReviewSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let duplicates = model.duplicates
        let plan = duplicates.plan
        let count = plan.steps.reduce(0) { $0 + $1.operations.count }
        VStack(alignment: .leading, spacing: Design.Spacing.xLarge) {
            VStack(alignment: .leading, spacing: Design.Spacing.tight) {
                Text("Remove \(count == 1 ? "1 duplicate" : "\(count.formatted()) duplicates")?")
                    .font(.title)
                    .bold()
                Text(summary(size: plan.totalSize))
                    .foregroundStyle(.quiet)
                    .fixedSize(horizontal: false, vertical: true)
            }

            GlassPanel {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(plan.steps) { step in
                            ReviewStepRow(step: step, isBlocked: false, showsDivider: step.id != plan.steps.first?.id)
                        }
                    }
                }
                .frame(minHeight: 60, maxHeight: 300)
                .scrollBounceBehavior(.basedOnSize)
            }

            VStack(alignment: .leading, spacing: Design.Spacing.small) {
                Text("Before you remove")
                    .font(.headline)
                    .foregroundStyle(.quiet)
                ForEach(checks(duplicates), id: \.text) { check in
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
                Button("Remove \(count == 1 ? "1 File" : "\(count.formatted()) Files")", action: duplicates.remove)
                    .buttonStyle(.primaryPill)
                    .disabled(plan.isEmpty)
            }
        }
        .padding(Design.Spacing.xLarge)
        .frame(width: Design.Size.sheetWidth)
        .presentationBackground {
            ThemeBackdrop()
        }
        .inkedSurface()
        .preferredColorScheme(.light)
    }

    private func cancel() {
        dismiss()
    }

    private func summary(size: Int64) -> String {
        let trash = "They go to the Trash. Nothing is deleted, and it can all be put back from the next screen."
        return size > 0 ? "\(trash) Emptying the Trash then gives back \(ByteFormat.string(size))." : trash
    }

    private func checks(_ duplicates: DuplicatesModel) -> [(text: String, isWarning: Bool)] {
        var checks: [(text: String, isWarning: Bool)] = [
            ("A copy of every file stays where it is. No group loses all its copies, whatever is ticked.", false),
            ("Each file is looked at again just before it is moved. One that changed since it was compared is left alone, and so is a whole group if the copy that was to stay is gone.", false),
        ]
        let sharing = duplicates.selectedSharing
        if sharing > 0 {
            checks.append(("\(sharing == 1 ? "1 of these shares its" : "\(sharing) of these share their") space with a copy that stays. Removing \(sharing == 1 ? "it" : "them") tidies up and gives nothing back.", true))
        }
        return checks
    }
}
