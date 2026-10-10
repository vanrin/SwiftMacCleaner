//
//  DuplicatePlan.swift
//  SwiftMacCleaner
//

import Foundation

/// Turns ticked duplicates into a plan the cleaner can carry out. Every file goes to the Trash, and
/// from no group does every copy go: one always stays, whatever is ticked.
nonisolated enum DuplicatePlan {
    static func stepID(for kind: DuplicateKind) -> String { "duplicates/\(kind.rawValue)" }

    /// A plan, with the ticked files that were left out of it and why.
    struct Checked: Sendable {
        var plan = CleanPlan()
        /// By file, the sentence for the receipt.
        var leftOut: [String: String] = [:]
    }

    static let changedReason = "changed since it was compared"
    static let keeperReason = "the copy that was to stay has changed or gone"

    /// The files of a group that a removal may take: ticked, free to go, and never all of them. When
    /// every copy is ticked, the one most worth keeping stays.
    static func going(from group: DuplicateGroup, selection: Set<String>) -> [DuplicateFile] {
        let chosen = group.files.filter { selection.contains($0.id) && !$0.isLocked }
        return chosen.count == group.files.count ? Array(chosen.dropFirst()) : chosen
    }

    /// One step per kind of file, in the order the kinds are listed.
    ///
    /// With `verifying` on, as it is just before a removal, each file is looked at again. A file that
    /// is no longer the one that was compared is left out, and so is a whole group none of whose
    /// staying copies is still the file it was: nothing is removed on the strength of a copy that may
    /// no longer be there.
    static func make(groups: [DuplicateGroup], selection: Set<String>, verifying: Bool = false) -> Checked {
        var checked = Checked()
        var operations: [DuplicateKind: [CleanOperation]] = [:]
        var counts: [DuplicateKind: Int] = [:]
        for group in groups {
            var going = going(from: group, selection: selection)
            guard !going.isEmpty else { continue }
            if verifying {
                let leaving = Set(going.map(\.id))
                guard group.files.contains(where: { !leaving.contains($0.id) && $0.isUnchanged }) else {
                    for file in going { checked.leftOut[file.id] = keeperReason }
                    continue
                }
                for file in going where !file.isUnchanged { checked.leftOut[file.id] = changedReason }
                going.removeAll { checked.leftOut[$0.id] != nil }
                guard !going.isEmpty else { continue }
            }
            let shares = group.shares(removing: going)
            operations[group.kind, default: []] += going.map {
                CleanOperation(itemID: $0.id, kind: .trash($0.url), size: shares[$0.id] ?? 0)
            }
            counts[group.kind, default: 0] += going.count
        }
        for kind in DuplicateKind.allCases {
            guard let steps = operations[kind], let count = counts[kind] else { continue }
            checked.plan.steps.append(CleanStep(
                id: stepID(for: kind),
                title: kind.title,
                tier: .review,
                method: .trash,
                summary: "Move \(count == 1 ? "1 duplicate" : "\(count) duplicates") to the Trash. A copy of each stays",
                size: steps.reduce(0) { $0 + $1.size },
                operations: steps
            ))
        }
        return checked
    }

    /// The outcome with the files that were left out before the run written into their steps, so the
    /// receipt accounts for everything that was ticked.
    static func recording(_ leftOut: [String: String], in outcome: CleanOutcome, groups: [DuplicateGroup]) -> CleanOutcome {
        guard !leftOut.isEmpty else { return outcome }
        var outcome = outcome
        var kinds: [String: DuplicateKind] = [:]
        for group in groups {
            for file in group.files where leftOut[file.id] != nil { kinds[file.id] = group.kind }
        }
        for (file, reason) in leftOut {
            guard let kind = kinds[file] else { continue }
            let id = stepID(for: kind)
            if let index = outcome.steps.firstIndex(where: { $0.id == id }) {
                outcome.steps[index].skippedItems[file] = reason
            } else {
                outcome.steps.append(StepOutcome(id: id, title: kind.title, method: .trash, size: 0, cleanedItemIDs: [],
                                                 failures: [], skippedItems: [file: reason]))
            }
        }
        return outcome
    }
}
