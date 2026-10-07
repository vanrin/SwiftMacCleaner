//
//  CleanPlan.swift
//  Mac Disk Cleaner
//

import Foundation

/// One action on disk, tagged with the item it belongs to.
nonisolated struct CleanOperation: Sendable, Hashable {
    enum Kind: Sendable, Hashable {
        case delete(URL)
        case trash(URL)
        case run([String])
        case runAsAdmin([String])
    }

    var itemID: String
    var kind: Kind
    /// The part of the item's size this operation accounts for.
    var size: Int64 = 0
}

/// Everything selected from one finding.
nonisolated struct CleanStep: Identifiable, Sendable {
    var id: String
    var title: String
    var tier: SafetyTier
    var method: CleanMethod
    var summary: String
    var size: Int64
    var operations: [CleanOperation]
    var waitsFor: InUseCheck?
}

nonisolated struct CleanPlan: Sendable {
    var steps: [CleanStep] = []

    var totalSize: Int64 { steps.reduce(0) { $0 + $1.size } }
    var trashedSize: Int64 { steps.filter { $0.method == .trash }.reduce(0) { $0 + $1.size } }
    var isEmpty: Bool { steps.isEmpty }
    var needsPassword: Bool { steps.contains { $0.method == .adminCommand } }

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
                }
            }
            guard !operations.isEmpty else { continue }
            plan.steps.append(CleanStep(
                id: finding.id,
                title: finding.title,
                tier: finding.tier,
                method: finding.method,
                summary: summary(for: finding, itemCount: items.count),
                size: items.reduce(0) { $0 + $1.size },
                operations: operations,
                waitsFor: finding.waitsFor
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
        }
    }

    /// The same clean-up as a script, for people who would rather read or keep it than click.
    func shellScript(date: Date = Date()) -> String {
        var lines = [
            "#!/bin/sh",
            "# Mac Disk Cleaner clean-up, written \(date.formatted(date: .abbreviated, time: .shortened))",
            "# Read it before you run it: rm -rf does not ask twice.",
        ]
        for step in steps {
            lines.append("")
            lines.append("# \(step.title) (\(ByteFormat.string(step.size)))")
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
                }
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func quote(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
