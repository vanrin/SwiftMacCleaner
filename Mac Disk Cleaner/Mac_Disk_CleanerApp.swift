//
//  Mac_Disk_CleanerApp.swift
//  Mac Disk Cleaner
//
//  Created by Chhea Vanrin on 6/10/26.
//

import SwiftUI

@main
enum Launcher {
    static func main() {
        #if DEBUG
        // `Mac Disk Cleaner --print-scan [area ...]` prints what a scan finds and exits.
        if let flag = CommandLine.arguments.firstIndex(of: "--print-scan") {
            ScanReportPrinter.run(areaNames: Array(CommandLine.arguments.dropFirst(flag + 1)))
            return
        }
        #endif
        Mac_Disk_CleanerApp.main()
    }
}

struct Mac_Disk_CleanerApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("Mac Disk Cleaner", id: "main") {
            RootView()
                .environment(model)
        }
        .defaultSize(width: 1100, height: 760)

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}

#if DEBUG
/// Runs the scanners without any window, for checking them against a real disk. Nothing is removed.
nonisolated enum ScanReportPrinter {
    static func run(areaNames: [String]) {
        let requested = areaNames.compactMap(Area.init(rawValue:))
        // Downloads and the Trash raise permission prompts, so they are only scanned when asked for.
        let areas = requested.isEmpty ? Area.allCases.filter { $0 != .installersTrash } : requested
        let roots = UserDefaults.standard.stringArray(forKey: "projectRoots") ?? AppSettings.detectedRoots()
        let context = ScanContext(
            home: FileManager.default.homeDirectoryForCurrentUser,
            projectRoots: roots.map { URL(fileURLWithPath: $0, isDirectory: true) }
        )

        let finished = DispatchSemaphore(value: 0)
        Task.detached {
            var total: Int64 = 0
            for area in areas {
                let started = Date()
                let result = await ScanEngine.scan(area, context: context)
                let seconds = String(format: "%.1f", Date().timeIntervalSince(started))
                print("\n## \(area.title)  (\(seconds) s)")
                if let reason = result.skipReason { print("   skipped: \(reason)") }
                for finding in result.findings {
                    total += finding.size
                    print("   [\(finding.tier.label)] \(finding.title): \(ByteFormat.string(finding.size)) in \(finding.items.count) items")
                    for item in finding.items.prefix(6) {
                        print("      \(ByteFormat.string(item.size).padding(toLength: 9, withPad: " ", startingAt: 0)) \(item.title)  |  \(item.detail)")
                    }
                    if let note = finding.note { print("      note: \(note)") }
                }
            }
            print("\nTotal found: \(ByteFormat.string(total))")
            fflush(stdout)
            finished.signal()
        }
        finished.wait()
    }
}
#endif
