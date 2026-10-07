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
        // `Mac Disk Cleaner --print-space <folder>` prints the largest folders inside it and exits.
        if let flag = CommandLine.arguments.firstIndex(of: "--print-space"),
           let folder = CommandLine.arguments.dropFirst(flag + 1).first {
            ScanReportPrinter.printSpace(folder: folder)
            return
        }
        #endif
        Mac_Disk_CleanerApp.main()
    }
}

struct Mac_Disk_CleanerApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        @Bindable var settings = model.settings
        Window("Mac Disk Cleaner", id: "main") {
            RootView()
                .environment(model)
                .task { model.startBackgroundChecks() }
        }
        .defaultSize(width: 1100, height: 760)

        Settings {
            SettingsView()
                .environment(model)
        }

        MenuBarExtra("Mac Disk Cleaner", systemImage: "internaldrive", isInserted: $settings.showsMenuBarItem) {
            MenuBarView()
                .environment(model)
        }
        .menuBarExtraStyle(.window)
    }
}

#if DEBUG
/// Runs the scanners without any window, for checking them against a real disk. Nothing is removed.
nonisolated enum ScanReportPrinter {
    static func run(areaNames: [String]) {
        let requested = areaNames.compactMap(Area.init(rawValue:))
        // Downloads, the Trash and device backups raise permission prompts, so those areas are only scanned when asked for.
        let prompting: Set<Area> = [.installersTrash, .leftovers, .snapshots]
        let areas = requested.isEmpty ? Area.allCases.filter { !prompting.contains($0) } : requested
        let context = AppSettings().scanContext()

        let finished = DispatchSemaphore(value: 0)
        Task.detached {
            var total: Int64 = 0
            var protectedTotal: Int64 = 0
            for area in areas {
                let started = Date()
                let result = await ScanEngine.scan(area, context: context)
                let seconds = String(format: "%.1f", Date().timeIntervalSince(started))
                print("\n## \(area.title)  (\(seconds) s)")
                if let reason = result.skipReason { print("   skipped: \(reason)") }
                for finding in result.findings {
                    total += finding.size
                    let size = finding.hasUnknownSize && finding.size == 0 ? "size unknown" : ByteFormat.string(finding.size)
                    let waits = finding.waitsFor.map { "  (waits for \($0.name))" } ?? ""
                    print("   [\(finding.tier.label)] \(finding.title): \(size) in \(finding.items.count) items, \(finding.method.verb.lowercased())\(waits)")
                    for item in finding.items.prefix(6) {
                        let itemSize = item.sizeUnknown ? "unknown" : ByteFormat.string(item.size)
                        print("      \(itemSize.padding(toLength: 9, withPad: " ", startingAt: 0)) \(item.title)  |  \(item.detail)")
                    }
                    if let note = finding.note { print("      note: \(note)") }
                }
                for item in result.protected {
                    protectedTotal += item.size ?? 0
                    let size = item.size.map(ByteFormat.string) ?? "kept"
                    print("   [Protected: \(item.rule.rawValue)] \(item.title): \(size)  |  \(item.why)")
                }
            }
            print("\nTotal found: \(ByteFormat.string(total)), left alone on purpose: \(ByteFormat.string(protectedTotal))")
            fflush(stdout)
            finished.signal()
        }
        finished.wait()
    }

    static func printSpace(folder: String) {
        let started = Date()
        var items = 0
        let root = SpaceScanner.measure(
            root: URL(fileURLWithPath: folder, isDirectory: true),
            threshold: SpaceScanner.listingThreshold
        ) { items = $0.items }
        guard let root else {
            print("Could not read \(folder)")
            return
        }
        let seconds = String(format: "%.1f", Date().timeIntervalSince(started))
        print("\(root.path): \(ByteFormat.string(root.size)), \(items) items in \(seconds) s\(root.isIncomplete ? " (incomplete)" : "")")
        for child in root.children.prefix(12) {
            print("  \(line(for: child))")
            for grandchild in child.children.prefix(3) {
                print("      \(line(for: grandchild))")
            }
        }
        print("  \(ByteFormat.string(root.smallerItemsSize).padding(toLength: 9, withPad: " ", startingAt: 0)) (smaller items)")
        fflush(stdout)
    }

    private static func line(for node: SpaceNode) -> String {
        let size = node.isUnreadable ? "unknown" : ByteFormat.string(node.size)
        let flag = node.isUnreadable ? "  [unreadable]" : node.isIncomplete ? "  [incomplete]" : ""
        return "\(size.padding(toLength: 9, withPad: " ", startingAt: 0)) \(node.name)\(node.isDirectory ? "/" : "")\(flag)"
    }
}
#endif
