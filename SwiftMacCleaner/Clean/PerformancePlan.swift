//
//  PerformancePlan.swift
//  SwiftMacCleaner
//

import Foundation

/// Turns what is ticked on the Performance screens into a plan the cleaner can carry out: tasks to run,
/// login items to take off the list, and launch agents to unload and move to the Trash.
nonisolated enum PerformancePlan {
    /// The tasks that run as root go in one step, so the password is asked for once.
    static let adminTasksStepID = "maintenance/admin"

    static func stepID(for task: MaintenanceTask) -> String { "maintenance/\(task.rawValue)" }
    static func stepID(for item: LoginItem) -> String { "login/\(item.id)" }
    static func stepID(for item: BackgroundItem) -> String { "background/\(item.id)" }

    // MARK: Maintenance tasks

    /// `executable` is this app's own program, for the task that runs it with a flag.
    static func tasks(_ checks: [MaintenanceCheck], selection: Set<MaintenanceTask>, mailIndex: URL?,
                      executable: String, uid: uid_t) -> CleanPlan {
        let chosen = checks.filter { selection.contains($0.task) && $0.isAvailable }
        var plan = CleanPlan()
        let admin = chosen.map(\.task).filter(\.needsPassword)
        if !admin.isEmpty {
            plan.steps.append(CleanStep(
                id: adminTasksStepID,
                title: titles(of: admin),
                aftermath: .rebuilds,
                method: .adminCommand,
                summary: "Run \(admin.map(\.actionTarget).joined(separator: "; ")), with your password",
                size: 0,
                operations: [CleanOperation(itemID: adminTasksStepID, kind: .runAsAdmin(adminShell(for: admin, uid: uid)))]
            ))
        }
        for check in chosen where !check.task.needsPassword {
            guard let command = check.task.userCommand(mailIndex: mailIndex, executable: executable) else { continue }
            let id = stepID(for: check.task)
            plan.steps.append(CleanStep(
                id: id,
                title: check.task.title,
                aftermath: .rebuilds,
                method: .command,
                summary: "Run \(check.task.actionTarget)",
                size: check.size,
                operations: [CleanOperation(itemID: id, kind: .run(command), size: check.size)],
                waitsFor: check.task.waitsFor,
                sizeIsEstimate: true
            ))
        }
        return plan
    }

    /// "Flush DNS Cache, Free Up Memory and Reindex Spotlight".
    static func titles(of tasks: [MaintenanceTask]) -> String {
        let names = tasks.map(\.title)
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + names.last!
    }

    /// One script that runs each task in turn and reports, on stderr, those that did not finish, so
    /// one failure neither stops the rest nor hides behind them.
    static func adminShell(for tasks: [MaintenanceTask], uid: uid_t) -> [String] {
        var lines = ["failed=''"]
        for task in tasks {
            guard let line = task.adminShellLine(uid: uid) else { continue }
            lines.append("{ \(line); } || failed=\"$failed \(task.rawValue)\"")
        }
        lines.append("if [ -n \"$failed\" ]; then echo \"failed:$failed\" >&2; exit 1; fi")
        return ["/bin/sh", "-c", lines.joined(separator: "; ")]
    }

    /// The tasks the script reported, read back from the failure the cleaner recorded.
    static func failedTasks(in failure: String) -> [MaintenanceTask] {
        guard let range = failure.range(of: "failed:", options: .backwards) else { return [] }
        return failure[range.upperBound...].split(separator: " ").compactMap { MaintenanceTask(rawValue: String($0)) }
    }

    // MARK: Login items

    static func loginItems(_ items: [LoginItem], selection: Set<String>) -> CleanPlan {
        var plan = CleanPlan()
        for item in items where selection.contains(item.id) {
            let id = stepID(for: item)
            plan.steps.append(CleanStep(
                id: id,
                title: item.name,
                aftermath: .downloadsAgain,
                method: .command,
                summary: "Take it off the Open at Login list. The app stays installed",
                size: 0,
                operations: [CleanOperation(itemID: id, kind: .run(LoginItemScanner.removeCommand(for: item)))]
            ))
        }
        return plan
    }

    // MARK: Background items

    static func backgroundItems(_ items: [BackgroundItem], selection: Set<String>, home: URL, uid: uid_t) -> CleanPlan {
        var plan = CleanPlan()
        for item in items where selection.contains(item.id) {
            let id = stepID(for: item)
            if item.needsPassword {
                plan.steps.append(CleanStep(
                    id: id,
                    title: item.title,
                    aftermath: .downloadsAgain,
                    method: .adminCommand,
                    summary: "Unload it and move \(item.plist.lastPathComponent) to the Trash, with your password",
                    size: 0,
                    operations: [CleanOperation(itemID: id, kind: .runAsAdmin(adminRemoveCommand(for: item, home: home, uid: uid)))]
                ))
            } else {
                var operations: [CleanOperation] = []
                if item.isLoaded != false {
                    operations.append(CleanOperation(itemID: id, kind: .run(unloadCommand(for: item, uid: uid, tolerant: item.isLoaded == nil))))
                }
                operations.append(CleanOperation(itemID: id, kind: .trash(item.plist)))
                plan.steps.append(CleanStep(
                    id: id,
                    title: item.title,
                    aftermath: .downloadsAgain,
                    method: .trash,
                    summary: "Unload it and move \(item.plist.lastPathComponent) to the Trash",
                    size: 0,
                    operations: operations
                ))
            }
        }
        return plan
    }

    /// Tells launchd to let the service go. `tolerant` swallows the error a service that is not loaded
    /// gives, for when launchd could not be asked beforehand.
    static func unloadCommand(for item: BackgroundItem, uid: uid_t, tolerant: Bool) -> [String] {
        unloadCommand(for: LaunchService(label: item.label, domain: item.domain), uid: uid, tolerant: tolerant)
    }

    static func unloadCommand(for service: LaunchService, uid: uid_t, tolerant: Bool) -> [String] {
        let target = "\(service.domain.launchdDomain(uid: uid))/\(service.label)"
        return tolerant
            ? ["/bin/sh", "-c", "/bin/launchctl bootout \(CleanPlan.quote(target)) >/dev/null 2>&1 || true"]
            : ["/bin/launchctl", "bootout", target]
    }

    /// Unloads a service whose plist belongs to root and moves the plist to the user's Trash, handed
    /// to the user so the Trash can be emptied without another password.
    static func adminRemoveCommand(for item: BackgroundItem, home: URL, uid: uid_t) -> [String] {
        let target = "\(item.domain.launchdDomain(uid: uid))/\(item.label)"
        let destination = home.appending(path: ".Trash").appending(path: item.plist.lastPathComponent).path
        let script = [
            "/bin/launchctl bootout \(CleanPlan.quote(target)) >/dev/null 2>&1",
            "d=\(CleanPlan.quote(destination))",
            "if [ -e \"$d\" ]; then d=\"$d.$(date +%s)\"; fi",
            "/bin/mv -f \(CleanPlan.quote(item.plist.path)) \"$d\" && /usr/sbin/chown \(uid) \"$d\"",
        ].joined(separator: "; ")
        return ["/bin/sh", "-c", script]
    }
}
