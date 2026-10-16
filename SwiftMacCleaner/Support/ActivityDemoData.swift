//
//  ActivityDemoData.swift
//  SwiftMacCleaner
//

import Foundation

/// Ten weeks of made-up work for the screens of My Activity, dated back from today so the page reads
/// the same whenever it is opened: 34 cleans, 71.4 GB cleaned in all, and the runs of the last weeks
/// as History lists them. Nothing here was done on this Mac.
nonisolated enum ActivityDemoData {
    static func records(now: Date = Date(), calendar: Calendar = .current) -> [ActivityRecord] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        func at(_ daysAgo: Int, _ hour: Int, _ minute: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now)) ?? now
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        func gb(_ value: Double) -> Int64 { Int64(value * 1_000_000_000) }
        typealias Line = ActivityRecord.Line
        var records: [ActivityRecord] = []

        // The weeks before: cleans of the developer areas, the system areas and apps' leftovers in turn.
        let developerSizes = [1.6, 0.9, 2.1, 1.2, 0.8, 1.9, 1.4, 1.1, 1.7, 1.3, 2.0, 0.9, 2.8]
        let systemSizes = [1.3, 0.9, 1.4, 1.0, 1.2, 0.8, 1.5, 1.1, 1.0, 1.3, 1.2, 1.09]
        let leftoverSizes = [0.4, 0.25, 0.35, 0.25]
        let developerNames = ["Xcode: DerivedData", "Old simulators", "npm and Yarn caches", "Docker build cache", "Gradle caches", "Unused toolchains"]
        let systemNames = ["App caches", "Logs", "Trash", "Browser caches"]
        let leftoverNames = ["Leftovers of Zoom", "Installers in Downloads", "Leftovers of Unity Hub", "Installers in Downloads"]
        var developer = 0, system = 0, leftover = 0
        for index in 0..<29 {
            let date = at(69 - Int(Double(index) * 1.5), 9 + index % 11, (index * 17) % 60)
            switch index % 7 {
            case 0, 2, 5:
                let size = developerSizes[developer]
                let first = developerNames[developer % developerNames.count], second = developerNames[(developer + 2) % developerNames.count]
                records.append(ActivityRecord(date: date, part: .developer, kind: .clean, title: "Cleaned \(first) and \(second)", lines: [
                    Line(what: first, fate: .deleted, size: gb(size * 0.7), part: .developer),
                    Line(what: second, fate: .deleted, size: gb(size) - gb(size * 0.7), part: .developer),
                ], itemCount: 40 + developer * 7))
                developer += 1
            case 4:
                let size = leftoverSizes[leftover]
                records.append(ActivityRecord(date: date, part: .apps, kind: .leftovers, title: "Removed \(3 + leftover) leftovers", lines: [
                    Line(what: leftoverNames[leftover], fate: .trashed, size: gb(size), part: .apps),
                ], itemCount: 3 + leftover))
                leftover += 1
            default:
                let size = systemSizes[system]
                let first = systemNames[system % systemNames.count], second = systemNames[(system + 1) % systemNames.count]
                records.append(ActivityRecord(date: date, part: .system, kind: .clean, title: "Cleaned \(first) and \(second)", lines: [
                    Line(what: first, fate: .deleted, size: gb(size * 0.8), part: .system),
                    Line(what: second, fate: second == "Trash" ? .trashEmptied : .deleted, size: gb(size) - gb(size * 0.8), part: .system),
                ], itemCount: 200 + system * 31))
                system += 1
            }
        }
        for (days, name, size) in [(66, "Skype", 0.6), (52, "Notion Calendar", 0.3), (44, "Unity Hub", 0.45), (35, "Steam", 0.25), (30, "Microsoft Teams", 0.3)] {
            records.append(ActivityRecord(date: at(days, 15, 10), part: .apps, kind: .uninstall, title: "Uninstalled \(name)",
                                          lines: [Line(what: name, fate: .trashed, size: gb(size), part: .apps)],
                                          itemCount: 6, appsUninstalled: 1))
        }
        for (days, apps) in [(63, ["Raycast", "Rectangle", "Ice"]), (49, ["Relay", "Raycast"]), (31, ["Rectangle", "Ice", "Relay"])] {
            records.append(ActivityRecord(date: at(days, 10, 2), part: .apps, kind: .updates, title: "Installed \(apps.count) updates with Homebrew",
                                          lines: apps.map { Line(what: $0, fate: .updated, note: "A newer version", part: .apps) },
                                          itemCount: apps.count, updatesInstalled: apps.count))
        }
        for days in [67, 58, 47, 38, 29] {
            let tasks: [MaintenanceTask] = [.flushDNS, .speedUpMail, .rebuildLaunchServices]
            records.append(ActivityRecord(date: at(days, 18, 45), part: .performance, kind: .tasks, title: "Ran 3 maintenance tasks",
                                          lines: tasks.map { Line(what: $0.title, fate: .ran, part: .performance) }, tasksRun: 3))
        }
        records.append(ActivityRecord(date: at(57, 11, 20), part: .performance, kind: .loginItems, title: "Removed 1 login item",
                                      lines: [Line(what: "Spotify", fate: .removed, part: .performance)], itemCount: 1, startupItemsRemoved: 1))
        records.append(ActivityRecord(date: at(41, 11, 20), part: .performance, kind: .backgroundItems, title: "Removed 3 background items",
                                      lines: ["Adobe Updater", "Zoom Helper", "Google Updater"].map { Line(what: $0, fate: .removed, part: .performance) },
                                      itemCount: 3, startupItemsRemoved: 3))
        for (days, copies, size) in [(54, 100, 0.45), (33, 74, 0.31)] {
            records.append(ActivityRecord(date: at(days, 21, 5), part: .duplicates, kind: .duplicates, title: "Removed \(copies) copies",
                                          lines: [Line(what: "\(copies) copies", fate: .trashed, size: gb(size), part: .duplicates)],
                                          itemCount: copies, copiesRemoved: copies))
        }

        // The last weeks, as History shows them.
        records.append(ActivityRecord(date: at(25, 20, 47), part: .largeFiles, kind: .clean, title: "Cleaned 6 old disk images", lines: [
            Line(what: "6 disk images in Downloads", fate: .trashed, size: gb(5.6), part: .largeFiles),
        ], itemCount: 6, logFile: "clean-demo-0921.log"))
        records.append(ActivityRecord(date: at(18, 11, 15), part: .overview, kind: .clean, title: "Cleaned 3 parts", lines: [
            Line(what: "Xcode: DerivedData", fate: .deleted, size: gb(11.4), part: .developer),
            Line(what: "Docker build cache", fate: .ran, size: gb(3.8), part: .developer),
            Line(what: "App caches", fate: .deleted, size: gb(2.9), part: .system),
            Line(what: "Leftovers of 3 apps", fate: .trashed, size: gb(0.6), part: .apps),
        ], itemCount: 2_906, logFile: "clean-demo-0928.log"))
        records.append(ActivityRecord(date: at(9, 16, 10), part: .developer, kind: .clean, title: "Cleaned Xcode: DerivedData and Old simulators", lines: [
            Line(what: "Xcode: DerivedData", fate: .deleted, size: gb(1.2), part: .developer),
            Line(what: "Old simulators", fate: .deleted, size: gb(0.4), part: .developer),
        ], itemCount: 96, logFile: "clean-demo-1007.log"))
        records.append(ActivityRecord(date: at(8, 9, 41), part: .apps, kind: .updates, title: "Installed 3 updates with Homebrew", lines: [
            Line(what: "Relay", fate: .updated, note: "2.4.1 → 2.5.0", part: .apps),
            Line(what: "Raycast", fate: .updated, note: "1.82.0 → 1.83.1", part: .apps),
            Line(what: "Rectangle", fate: .updated, note: "0.84 → 0.85", part: .apps),
        ], itemCount: 3, updatesInstalled: 3))
        records.append(ActivityRecord(date: at(7, 18, 2), part: .duplicates, kind: .duplicates, title: "Removed 38 copies", lines: [
            Line(what: "38 copies", fate: .trashed, size: gb(0.64), part: .duplicates),
        ], itemCount: 38, copiesRemoved: 38, logFile: "clean-demo-1009.log"))
        records.append(ActivityRecord(date: at(6, 22, 32), part: .system, kind: .clean, title: "Cleaned App caches, Logs and Trash", lines: [
            Line(what: "App caches", fate: .deleted, size: gb(1.1), part: .system),
            Line(what: "Logs", fate: .deleted, size: gb(0.096), part: .system),
            Line(what: "Trash", fate: .trashEmptied, size: gb(0.214), part: .system),
        ], itemCount: 1_284, logFile: "clean-demo-1010.log"))
        var tasks = ActivityRecord(date: at(3, 12, 24), part: .performance, kind: .tasks, title: "Ran 2 maintenance tasks", lines: [
            Line(what: MaintenanceTask.flushDNS.title, fate: .ran, part: .performance),
            Line(what: MaintenanceTask.purgeableSpace.title, fate: .ran, part: .performance),
        ], tasksRun: 2, logFile: "clean-demo-1013a.log")
        tasks.note = "macOS gave back 3.9 GB of purgeable space, which is not counted as cleaned."
        records.append(tasks)
        records.append(ActivityRecord(date: at(3, 14, 34), part: .apps, kind: .uninstall, title: "Uninstalled OpenWorker", lines: [
            Line(what: "OpenWorker", fate: .trashed, size: gb(0.151), part: .apps),
        ], itemCount: 2, appsUninstalled: 1, logFile: "clean-demo-1013b.log"))
        let images = ["Xcode_26.dmg", "Figma-old.dmg"].enumerated().map { index, name in
            TrashedItem(original: home.appending(path: "Downloads/\(name)"), inTrash: home.appending(path: ".Trash/\(name)"),
                        size: index == 0 ? gb(0.62) : gb(0.2))
        }
        records.append(ActivityRecord(date: at(2, 10, 25), part: .overview, kind: .clean, title: "Cleaned 3 parts and ran 2 tasks", lines: [
            Line(what: "Xcode: DerivedData and old simulators", fate: .deleted, size: gb(4.7), part: .developer),
            Line(what: "Caches and logs", fate: .deleted, size: gb(0.502), part: .system),
            Line(what: "2 disk images", fate: .trashed, size: gb(0.82), part: .largeFiles),
            Line(what: MaintenanceTask.flushDNS.title, fate: .ran, part: .performance),
            Line(what: MaintenanceTask.speedUpMail.title, fate: .ran, part: .performance),
            Line(what: "Google Chrome's cache", fate: .waited, size: gb(1.7), note: "Google Chrome was still open", part: .system),
        ], trashed: images.map { ActivityRecord.Trashed(item: $0, part: .largeFiles) },
           itemCount: 412, tasksRun: 2, logFile: "clean-demo-1014.log"))
        return records.sorted { $0.date < $1.date }
    }

    /// How the made-up Protection check found the Mac, three days ago.
    static func protection(now: Date = Date()) -> ProtectionSnapshot {
        let findings = ProtectionScanner.findings(from: ProtectionDemoData.facts())
        return ProtectionSnapshot(date: now.addingTimeInterval(-3 * 86_400), settings: findings.map { finding in
            let state: ProtectionSnapshot.Setting.State = switch finding.state {
            case .inPlace: .inPlace
            case .needsLook: .needsLook
            case .unknown: .unknown
            }
            return ProtectionSnapshot.Setting(name: finding.check.title, status: finding.status, state: state)
        })
    }
}
