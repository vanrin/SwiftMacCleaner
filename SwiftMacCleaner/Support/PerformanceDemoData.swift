//
//  PerformanceDemoData.swift
//  SwiftMacCleaner
//

#if DEBUG
import Foundation

/// Made-up findings for looking at the Performance screens without probing or changing a real Mac.
/// Launch with `--demo performance`, followed by `intro`, `scanning`, `summary`, `manager`, `login`,
/// `background`, `review`, `running` or `done`. `--demo performance scan` runs the real scan, which only reads.
nonisolated enum PerformanceDemoData {
    static func checks() -> [MaintenanceCheck] {
        let now = Date()
        var facts = MaintenanceScanner.Facts()
        facts.purgeable = 4_700_000_000
        facts.freeMemoryPercent = 61
        facts.spotlightIndexing = true
        facts.mailIndex = .found(URL(fileURLWithPath: "/Users/demo/Library/Mail/V10/MailData/Envelope Index"), 1_380_000_000)
        return MaintenanceScanner.checks(facts: facts, lastRuns: [.freeMemory: now.addingTimeInterval(-3 * 86_400)], now: now)
    }

    static func loginItems() -> [LoginItem] {
        [
            LoginItem(name: "Harbor", path: URL(fileURLWithPath: "/Applications/Harbor.app")),
            LoginItem(name: "Keyframe", path: URL(fileURLWithPath: "/Applications/Keyframe.app"), isHidden: true),
            LoginItem(name: "Tally", path: URL(fileURLWithPath: "/Applications/Tally.app"), exists: false),
        ]
    }

    static func backgroundItems(home: URL) -> [BackgroundItem] {
        let user = home.appending(path: "Library/LaunchAgents")
        let agents = URL(fileURLWithPath: "/Library/LaunchAgents", isDirectory: true)
        let daemons = URL(fileURLWithPath: "/Library/LaunchDaemons", isDirectory: true)
        func item(_ folder: URL, _ label: String, _ domain: BackgroundItem.Domain, app: String? = nil, program: String,
                  runsAtLoad: Bool = false, keepsAlive: Bool = false, interval: TimeInterval? = nil, running: Bool = false) -> BackgroundItem {
            var item = BackgroundItem(plist: folder.appending(path: "\(label).plist"), label: label, domain: domain, program: program)
            item.appName = app
            item.appURL = app.map { URL(fileURLWithPath: "/Applications/\($0).app") }
            item.runsAtLoad = runsAtLoad
            item.keepsAlive = keepsAlive
            item.interval = interval
            item.isLoaded = true
            item.isRunning = running
            return item
        }
        return [
            item(user, "com.example.harbor.helper", .userAgent, app: "Harbor", program: "/Applications/Harbor.app/Contents/MacOS/HarborHelper", runsAtLoad: true, keepsAlive: true, running: true),
            item(user, "com.example.keyframe.updater", .userAgent, app: "Keyframe", program: "/Applications/Keyframe.app/Contents/Library/LaunchAgents/Updater.app/Contents/MacOS/Updater", interval: 3600),
            item(user, "com.example.inkwell.sync", .userAgent, app: "Inkwell", program: "/Applications/Inkwell.app/Contents/MacOS/InkwellSync", runsAtLoad: true),
            item(agents, "com.example.tally.login.check", .systemAgent, app: "Tally", program: "/Applications/Tally.app/Contents/MacOS/TallyCheck", runsAtLoad: true),
            item(daemons, "com.example.harbor.vmnetd", .systemDaemon, program: "/Library/PrivilegedHelperTools/com.example.harbor.vmnetd", runsAtLoad: true, running: true),
            item(daemons, "com.example.harbor.socket", .systemDaemon, program: "/Library/PrivilegedHelperTools/com.example.harbor.socket"),
            item(daemons, "org.example.tunnel.helper", .systemDaemon, program: "/Library/PrivilegedHelperTools/org.example.tunnel.helper", keepsAlive: true, running: true),
        ]
    }

    /// A receipt for the plan, with the one step that runs as root reporting one task that did not finish.
    static func outcome(for plan: CleanPlan) -> CleanOutcome {
        let steps = plan.steps.map { step in
            StepOutcome(
                id: step.id, title: step.title, method: step.method, size: step.size,
                cleanedItemIDs: step.id == PerformancePlan.stepID(for: .speedUpMail) ? [] : [step.id],
                failures: [],
                skippedReason: step.id == PerformancePlan.stepID(for: .speedUpMail) ? InUseCheck.app(bundleID: "com.apple.mail", name: "Mail").skipReason : nil
            )
        }
        let free = DiskInfo.current().free
        return CleanOutcome(steps: steps, freeBefore: free, freeAfter: free + 4_100_000_000, trashedSize: 0, duration: 48, logURL: nil, started: Date())
    }
}
#endif
