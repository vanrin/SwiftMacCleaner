//
//  CleanPlan.swift
//  SwiftMacCleaner
//

import Foundation

/// One action on disk, tagged with the item it belongs to.
nonisolated struct CleanOperation: Sendable, Hashable {
    enum Kind: Sendable, Hashable {
        case delete(URL)
        case trash(URL)
        case run([String])
        case runAsAdmin([String])
        /// Something root deletes. A step's targets all go into one script, so there is one password prompt.
        case deleteAsAdmin(SystemLogs.Target)
    }

    var itemID: String
    var kind: Kind
    /// The part of the item's size this operation accounts for.
    var size: Int64 = 0
}

/// What becomes of a step's items, which is how the confirmation groups them: in the order of how
/// final each is.
nonisolated enum CleanFate: Int, CaseIterable, Identifiable, Sendable {
    case deleted, trashEmptied, deletedAsRoot, run, trashed

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .deleted: "Deleted right away"
        case .trashEmptied: "Trash emptied"
        case .deletedAsRoot: "Removed with your password"
        case .run: "Run as they are"
        case .trashed: "Moved to the Trash"
        }
    }

    var detail: String {
        switch self {
        case .deleted: "Whatever made them makes them again."
        case .trashEmptied: "They cannot be put back."
        case .deletedAsRoot: "Old logs that belong to root. Newer ones stay, and so does every folder."
        case .run: "Tools and tasks do the removing, which cannot be undone."
        case .trashed: "They can be put back until you empty the Trash."
        }
    }
}

/// Everything selected from one finding.
nonisolated struct CleanStep: Identifiable, Sendable {
    var id: String
    var title: String
    var aftermath: Aftermath
    var method: CleanMethod
    var summary: String
    var size: Int64
    var operations: [CleanOperation]
    var waitsFor: InUseCheck?
    /// The rest of the step depends on its first operation. When moving an app fails, its files stay.
    var requiresFirst = false
    /// False for what apps write to all the time: a change since the scan is no reason to leave it.
    var checksFreshness = true
    /// The size is a guess at what a task gives back, not something measured. It is shown as "up to"
    /// and counted in no total.
    var sizeIsEstimate = false

    var fate: CleanFate {
        switch method {
        case .delete: aftermath == .discarded ? .trashEmptied : .deleted
        case .trash: .trashed
        case .command, .adminCommand: .run
        case .adminDelete: .deletedAsRoot
        }
    }
}

nonisolated struct CleanPlan: Sendable {
    var steps: [CleanStep] = []

    var totalSize: Int64 { steps.reduce(0) { $0 + $1.size } }

    /// What the plan removes when some of it has to wait: the steps in `blocked` and the items in
    /// `waiting` are left out, and so is every size that is only a guess. The round button and the
    /// confirmation both show this, so they cannot disagree.
    func size(leavingOut blocked: Set<String> = [], waiting: Set<String> = []) -> Int64 {
        steps.filter { !blocked.contains($0.id) && !$0.sizeIsEstimate }.reduce(0) { total, step in
            total + step.operations.filter { !waiting.contains($0.itemID) }.reduce(0) { $0 + $1.size }
        }
    }

    /// How much of the plan waits on the items in `waiting`, among the steps that are not blocked whole.
    func waitingSize(blocked: Set<String> = [], waiting: Set<String>) -> Int64 {
        steps.filter { !blocked.contains($0.id) }.flatMap(\.operations).filter { waiting.contains($0.itemID) }.reduce(0) { $0 + $1.size }
    }
    var trashedSize: Int64 { steps.filter { $0.method == .trash }.reduce(0) { $0 + $1.size } }
    var isEmpty: Bool { steps.isEmpty }
    var needsPassword: Bool { passwordPromptCount > 0 }
    /// How often macOS asks for the password: once for each step that needs root.
    var passwordPromptCount: Int { steps.count { $0.method.needsPassword } }
    /// "once", "twice" or "3 times", for a sentence about the prompts.
    var passwordPromptTimes: String {
        switch passwordPromptCount {
        case 1: "once"
        case 2: "twice"
        case let count: "\(count) times"
        }
    }
    /// What goes for good, with no copy left in the Trash.
    var finalSize: Int64 { totalSize - trashedSize }

    /// The plan without the steps that need a password, for a clean nobody is there to answer a prompt for.
    var withoutPasswordSteps: CleanPlan { CleanPlan(steps: steps.filter { !$0.method.needsPassword }) }

    /// Builds the plan for the ticked items, keeping the order the findings are shown in.
    static func make(findings: [Finding], selection: Set<String>) -> CleanPlan {
        var plan = CleanPlan()
        for finding in findings {
            let items = finding.items.filter { selection.contains($0.id) }
            guard !items.isEmpty else { continue }
            var operations: [CleanOperation] = []
            for item in items {
                switch finding.method {
                case .delete:
                    operations += item.paths.enumerated().map {
                        CleanOperation(itemID: item.id, kind: .delete($1), size: $0 == 0 ? item.size : 0)
                    }
                case .trash:
                    operations += item.paths.enumerated().map {
                        CleanOperation(itemID: item.id, kind: .trash($1), size: $0 == 0 ? item.size : 0)
                    }
                case .command:
                    if let command = item.command {
                        operations.append(CleanOperation(itemID: item.id, kind: .run(command), size: item.size))
                    }
                case .adminCommand:
                    if let command = item.command {
                        operations.append(CleanOperation(itemID: item.id, kind: .runAsAdmin(command), size: item.size))
                    }
                case .adminDelete:
                    if let target = item.systemTarget {
                        operations.append(CleanOperation(itemID: item.id, kind: .deleteAsAdmin(target), size: item.size))
                    }
                }
            }
            guard !operations.isEmpty else { continue }
            plan.steps.append(CleanStep(
                id: finding.id,
                title: finding.title,
                aftermath: finding.aftermath,
                method: finding.method,
                summary: summary(for: finding, itemCount: items.count),
                size: items.reduce(0) { $0 + $1.size },
                operations: operations,
                waitsFor: finding.waitsFor,
                checksFreshness: !finding.keepsChanging
            ))
        }
        return plan
    }

    private static func summary(for finding: Finding, itemCount: Int) -> String {
        let items = itemCount == 1 ? "1 item" : "\(itemCount) items"
        switch finding.method {
        case .delete: return "Delete \(items) · \(finding.actionTarget)"
        case .trash: return "Move \(items) to the Trash"
        case .command: return "Run \(finding.actionTarget)"
        case .adminCommand: return "Run \(finding.actionTarget), with your password"
        case .adminDelete: return "Delete old logs in \(itemCount == 1 ? "1 place" : "\(itemCount) places"), with your password"
        }
    }

    /// The same clean-up as a script, for people who would rather read or keep it than click.
    func shellScript(date: Date = Date()) -> String {
        var lines = [
            "#!/bin/sh",
            "# SwiftMacCleaner clean-up, written \(date.formatted(date: .abbreviated, time: .shortened))",
            "# Read it before you run it: rm -rf does not ask twice.",
        ]
        for step in steps {
            lines.append("")
            lines.append("# \(step.title) (\(ByteFormat.string(step.size)))")
            // What root deletes goes into one script, the same one the app would hand to root.
            let targets = step.operations.compactMap { operation -> SystemLogs.Target? in
                if case .deleteAsAdmin(let target) = operation.kind { target } else { nil }
            }
            if !targets.isEmpty {
                lines.append("sudo " + SystemLogs.command(for: targets).map(Self.quote).joined(separator: " "))
            }
            for operation in step.operations {
                switch operation.kind {
                case .delete(let url):
                    lines.append("rm -rf -- \(Self.quote(url.path))")
                case .trash(let url):
                    lines.append("mv -- \(Self.quote(url.path)) ~/.Trash/")
                case .run(let command):
                    lines.append(command.map(Self.quote).joined(separator: " "))
                case .runAsAdmin(let command):
                    lines.append("sudo " + command.map(Self.quote).joined(separator: " "))
                case .deleteAsAdmin:
                    break
                }
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func quote(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
