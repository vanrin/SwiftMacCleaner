//
//  XcodeScanner.swift
//  SwiftMacCleaner
//

import Foundation

nonisolated enum XcodeScanner {
    static let oldXcodesFindingID = "xcode.oldVersions"

    static func scan(_ context: ScanContext) async -> AreaScanResult {
        let developer = context.home.appending(path: "Library/Developer")
        guard Files.isDirectory(developer.appending(path: "Xcode"))
                || Files.isDirectory(developer.appending(path: "CoreSimulator")) else {
            return AreaScanResult(skipReason: "Xcode has not been used on this Mac.")
        }
        var result = AreaScanResult()
        let derived = await derivedData(context)
        if let finding = derived.finding { result.findings.append(finding) }
        result.protected += derived.protected
        if let finding = await deviceSupport(context) { result.findings.append(finding) }
        if let finding = await CatalogScanner.finding(for: Catalog.xcodeCaches, context: context) { result.findings.append(finding) }
        if let finding = await CatalogScanner.finding(for: Catalog.xcodeLeftovers, context: context) { result.findings.append(finding) }
        let simulators = simulators(context)
        if let finding = simulators.finding { result.findings.append(finding) }
        result.protected += simulators.protected
        if let json = simulators.devicesJSON,
           let finding = await simulatorCaches(fromJSON: json, offered: Set(simulators.finding?.items.map(\.id) ?? []),
                                               context: context) {
            result.findings.append(finding)
        }
        if let finding = await archives(context) { result.findings.append(finding) }
        let xcodes = await oldXcodes(context)
        if let finding = xcodes.finding { result.findings.append(finding) }
        result.protected += xcodes.protected
        return result
    }

    // MARK: DerivedData

    private static func derivedData(_ context: ScanContext) async -> (finding: Finding?, protected: [ProtectedItem]) {
        let root = context.home.appending(path: "Library/Developer/Xcode/DerivedData")
        let folders = Files.subdirectories(of: root)
        guard !folders.isEmpty else { return (nil, []) }
        let sizes = await Sizing.sizes(of: folders)

        var items: [FindingItem] = []
        var protected: [ProtectedItem] = []
        var keptSize: Int64 = 0
        for folder in folders {
            let size = sizes[folder] ?? 0
            guard size >= 1_000_000 else { continue }
            let entry = derivedDataEntry(folder, context: context)
            if let lastUsed = entry.lastUsed, lastUsed > context.recentBuildCutoff {
                keptSize += size
                protected.append(ProtectedItem(
                    id: "xcode.derivedData/recent/\(folder.lastPathComponent)",
                    area: .xcode,
                    title: "\(entry.title) DerivedData",
                    why: "Built \(context.relative(lastUsed)). Its build cache is still saving you time",
                    rule: .recentlyUsed,
                    size: size
                ))
                continue
            }
            items.append(FindingItem(
                id: "xcode.derivedData/\(folder.lastPathComponent)",
                title: entry.title,
                detail: entry.detail,
                size: size,
                paths: [folder]
            ))
        }
        guard !items.isEmpty else { return (nil, protected) }
        items.sort { $0.size > $1.size }

        var note: String?
        if !protected.isEmpty {
            let projects = protected.count == 1 ? "1 project" : "\(protected.count) projects"
            note = "Left out on purpose: \(projects) built in the last \(context.recentBuildDays) days, "
                + "\(ByteFormat.string(keptSize)). Their build cache is still saving you time."
        }
        let finding = Finding(
            id: "xcode.derivedData",
            area: .xcode,
            aftermath: .rebuilds,
            title: "Xcode DerivedData",
            summary: "\(context.tilde(root)), \(items.count) \(items.count == 1 ? "folder" : "folders")",
            explanation: "Build products and indexes. Xcode recreates them on the next build, which will take longer than usual.",
            method: .delete,
            actionTarget: context.tilde(root),
            items: items,
            note: note,
            waitsFor: .xcode
        )
        return (finding, protected)
    }

    private static func derivedDataEntry(_ folder: URL, context: ScanContext) -> (title: String, detail: String, lastUsed: Date?) {
        let folderName = folder.lastPathComponent
        let projectName = projectName(fromFolder: folderName)
        guard let info = Files.plist(at: folder.appending(path: "info.plist")) else {
            // A project folder that lost its record is a leftover; anything else is a cache Xcode shares.
            return projectName.map { ($0, "Leftover build folder with no project record", nil) }
                ?? (folderName, "Shared build cache", nil)
        }
        let title = projectName ?? folderName
        let lastUsed = info["LastAccessedDate"] as? Date
        if let workspace = info["WorkspacePath"] as? String,
           canCheckExistence(of: workspace, context: context),
           !FileManager.default.fileExists(atPath: workspace) {
            return (title, "The project folder no longer exists", nil)
        }
        return (title, lastUsed.map { "Last built \(context.relative($0))" } ?? "Build products and indexes", lastUsed)
    }

    /// "MyApp-gkqxyzabcdefghijklmnopqrstuv" -> "MyApp". Xcode appends 28 lowercase letters to a project's folder.
    static func projectName(fromFolder folderName: String) -> String? {
        guard let dash = folderName.lastIndex(of: "-") else { return nil }
        let hash = folderName[folderName.index(after: dash)...]
        let name = folderName[..<dash]
        guard hash.count == 28, hash.allSatisfy({ $0.isLowercase && $0.isLetter }), !name.isEmpty else { return nil }
        return String(name)
    }

    /// Looking inside Documents, Desktop or another volume can raise a permission prompt or give a
    /// false "missing", so the "no longer exists" label is only used where the answer is reliable.
    private static func canCheckExistence(of path: String, context: ScanContext) -> Bool {
        let home = context.home.path
        guard path.hasPrefix(home + "/") else { return false }
        let guarded = ["Documents", "Desktop", "Downloads", "Library/Mobile Documents", "Library/CloudStorage"]
        return !guarded.contains { path.hasPrefix("\(home)/\($0)/") }
    }

    // MARK: Device support

    private static func deviceSupport(_ context: ScanContext) async -> Finding? {
        let xcode = context.home.appending(path: "Library/Developer/Xcode")
        let families = [
            ("iOS", "iOS DeviceSupport"), ("watchOS", "watchOS DeviceSupport"), ("tvOS", "tvOS DeviceSupport"),
            ("visionOS", "visionOS DeviceSupport"), ("visionOS", "xrOS DeviceSupport"),
        ]
        var candidates: [PathCandidate] = []
        for (platform, folderName) in families {
            let folders = Files.subdirectories(of: xcode.appending(path: folderName))
            let choices = deviceSupportChoices(folders.map(\.lastPathComponent))
            for folder in folders {
                let name = folder.lastPathComponent
                let choice = choices[name] ?? .older
                let detail = switch choice {
                case .newestForModel(let model): "Newest \(platform) version for \(model), kept by default"
                case .newestMajor: "Newest \(platform) version on this Mac, kept by default"
                case .replaced(let model, let newer): "Older \(platform) version for \(model), which has \(newer) here too"
                case .older: "Older \(platform) version"
                }
                candidates.append(PathCandidate(
                    title: "\(platform) \(name)",
                    detail: detail,
                    url: folder,
                    preselected: choice.isKept ? false : nil
                ))
            }
        }
        let items = await Sizing.items(prefix: "xcode.deviceSupport", from: candidates)
        guard !items.isEmpty else { return nil }
        return Finding(
            id: "xcode.deviceSupport",
            area: .xcode,
            aftermath: .rebuilds,
            title: "Device support",
            summary: "Debug symbols for \(items.count) OS \(items.count == 1 ? "version" : "versions") copied from your devices",
            explanation: "Debug symbols copied from devices you plugged in. They are copied again the next time that OS version connects.",
            method: .delete,
            actionTarget: context.tilde(xcode.appending(path: "iOS DeviceSupport")),
            items: items
        )
    }

    /// Why a device support folder is kept by default, or why it is offered.
    enum SupportChoice: Equatable {
        /// The newest version copied from this device model.
        case newestForModel(String)
        /// A folder with no model in its name, from the newest major version.
        case newestMajor
        /// An older version for a model that has a newer one here as well.
        case replaced(model: String, newer: String)
        case older

        var isKept: Bool {
            switch self {
            case .newestForModel, .newestMajor: true
            case .replaced, .older: false
            }
        }
    }

    /// What becomes of each folder, by name.
    ///
    /// Xcode names a folder after the device model and its system, as in "iPhone17,2 27.0 (24A437)".
    /// Updating the phone to 27.0.1 makes Xcode copy a whole new folder and leave the old one, so for
    /// each model only the newest version is kept. Folders from older Xcode versions carry no model
    /// ("17.5 (21F79)") and cannot be told apart by device, so every one of the newest major is kept.
    static func deviceSupportChoices(_ names: [String]) -> [String: SupportChoice] {
        let parsed = names.compactMap { name in deviceSupportVersion(in: name).map { (name, $0.model, $0.version) } }
        var newestForModel: [String: [Int]] = [:]
        for (_, model, version) in parsed {
            guard let model else { continue }
            if newestForModel[model].map({ $0.lexicographicallyPrecedes(version) }) ?? true { newestForModel[model] = version }
        }
        let newestMajor = parsed.filter { $0.1 == nil }.compactMap(\.2.first).max()

        var choices: [String: SupportChoice] = [:]
        for (name, model, version) in parsed {
            if let model, let newest = newestForModel[model] {
                choices[name] = version == newest
                    ? .newestForModel(model)
                    : .replaced(model: model, newer: newest.map(String.init).joined(separator: "."))
            } else {
                choices[name] = version.first == newestMajor ? .newestMajor : .older
            }
        }
        return choices
    }

    /// "iPhone17,2 27.0.1 (24A446)" -> ("iPhone17,2", [27, 0, 1]), "17.5 (21F79)" -> (nil, [17, 5]).
    static func deviceSupportVersion(in folderName: String) -> (model: String?, version: [Int])? {
        let tokens = folderName.split(separator: " ")
        guard let index = tokens.firstIndex(where: { token in
            token.first?.isNumber == true && token.allSatisfy { $0.isNumber || $0 == "." }
        }) else { return nil }
        let version = tokens[index].split(separator: ".").compactMap { Int($0) }
        let model = index > 0 ? tokens[..<index].joined(separator: " ") : nil
        return (model, version)
    }

    /// "iPhone15,2 17.5 (21F79)" -> 17
    static func majorVersion(in folderName: String) -> Int? {
        for token in folderName.split(separator: " ") {
            let digits = token.prefix { $0.isNumber }
            if !digits.isEmpty, token.allSatisfy({ $0.isNumber || $0 == "." }), let major = Int(digits) {
                return major
            }
        }
        return nil
    }

    // MARK: Simulators

    struct SimDeviceList: Decodable {
        var devices: [String: [SimDevice]]
    }

    struct SimDevice: Decodable {
        var udid: String
        var name: String
        var state: String?
        var isAvailable: Bool?
        var dataPathSize: Int64?
        var lastUsedAt: String?
    }

    struct SimRuntime: Decodable {
        var identifier: String
        var version: String?
        var platformIdentifier: String?
        var sizeBytes: Int64?
        var state: String?
        var deletable: Bool?
        var lastUsedAt: String?
    }

    /// The simulators worth offering, the ones left alone, and what `simctl` said about the devices.
    private static func simulators(_ context: ScanContext) -> (finding: Finding?, protected: [ProtectedItem], devicesJSON: String?) {
        guard let xcrun = Shell.which("xcrun") else { return (nil, [], nil) }
        var items: [FindingItem] = []
        var protected: [ProtectedItem] = []
        var devicesJSON: String?
        if let output = Shell.run(xcrun, ["simctl", "list", "devices", "-j"], timeout: 40), output.succeeded {
            devicesJSON = output.stdout
            let report = deviceReport(fromJSON: output.stdout, xcrun: xcrun, context: context)
            items += report.items
            protected += report.protected
        }
        if let output = Shell.run(xcrun, ["simctl", "runtime", "list", "-j"], timeout: 40), output.succeeded {
            let report = runtimeReport(fromJSON: output.stdout, xcrun: xcrun, context: context)
            items += report.items
            protected += report.protected
        }
        guard !items.isEmpty else { return (nil, protected, devicesJSON) }
        items.sort { $0.size > $1.size }
        let finding = Finding(
            id: "xcode.simulators",
            area: .xcode,
            aftermath: .downloadsAgain,
            title: "Simulator runtimes and devices",
            summary: "\(items.count) \(items.count == 1 ? "item" : "items") you have not used in \(context.staleDays)+ days",
            explanation: "Runtimes and devices you have not used in a while. A runtime is a multi-gigabyte download from Xcode if you need it back, and a deleted device loses its installed apps and data. Booted devices and the newest runtime for each platform are never offered.",
            method: .command,
            actionTarget: "xcrun simctl delete, xcrun simctl runtime delete",
            items: items
        )
        return (finding, protected, devicesJSON)
    }

    // MARK: Caches inside simulators

    static let simulatorCachesFindingID = "xcode.simulatorCaches"

    /// What the simulators the scan keeps have cached inside themselves: downloads, media analysis,
    /// maps tiles and the like, which the simulated system rebuilds once the device boots again.
    /// A booted device is left alone, and so is a device that is offered whole. Only what is inside
    /// each device's Caches folder goes; the folder itself stays.
    static func simulatorCaches(fromJSON json: String, offered: Set<String>, context: ScanContext) async -> Finding? {
        let groups = simulatorCacheGroups(fromJSON: json, offered: offered, context: context)
        let items = await Sizing.items(prefix: simulatorCachesFindingID, from: groups, minimumSize: 20_000_000)
        guard !items.isEmpty else { return nil }
        return Finding(
            id: simulatorCachesFindingID,
            area: .xcode,
            aftermath: .rebuilds,
            title: "Caches inside simulators",
            summary: "\(items.count) shut-down \(items.count == 1 ? "simulator" : "simulators") you keep",
            explanation: "Caches the simulated system keeps inside each device, such as downloads, media analysis and map tiles. The device rebuilds them as it runs. Installed apps and their data are left alone, and a booted device is never touched.",
            method: .delete,
            actionTarget: "~/Library/Developer/CoreSimulator/Devices/*/data/Library/Caches",
            items: items,
            waitsFor: .app(bundleID: "com.apple.iphonesimulator", name: "Simulator")
        )
    }

    /// One group per shut-down device that is kept, made of what sits in its Caches folder.
    static func simulatorCacheGroups(fromJSON json: String, offered: Set<String>, context: ScanContext) -> [PathGroup] {
        guard let list = try? JSONDecoder().decode(SimDeviceList.self, from: Data(json.utf8)) else { return [] }
        let devices = context.home.appending(path: "Library/Developer/CoreSimulator/Devices")
        var groups: [PathGroup] = []
        for (runtimeKey, entries) in list.devices {
            for device in entries where device.isAvailable != false && device.state != "Booted" {
                guard !offered.contains("xcode.simulators/device/\(device.udid)") else { continue }
                let caches = devices.appending(path: "\(device.udid)/data/Library/Caches")
                groups.append(PathGroup(
                    id: device.udid,
                    title: "\(device.name) (\(runtimeName(fromKey: runtimeKey)))",
                    detail: device.lastUsedAt.flatMap(date(from:)).map { "Shut down, last used \(context.relative($0))" } ?? "Shut down",
                    paths: Files.children(of: caches).filter { !Files.isSymlink($0) }
                ))
            }
        }
        return groups
    }

    static func deviceItems(fromJSON json: String, xcrun: String, context: ScanContext) -> [FindingItem] {
        deviceReport(fromJSON: json, xcrun: xcrun, context: context).items
    }

    /// Devices worth offering, and the booted ones that were left alone.
    static func deviceReport(fromJSON json: String, xcrun: String, context: ScanContext) -> (items: [FindingItem], protected: [ProtectedItem]) {
        guard let list = try? JSONDecoder().decode(SimDeviceList.self, from: Data(json.utf8)) else { return ([], []) }
        var items: [FindingItem] = []
        var protected: [ProtectedItem] = []

        let unavailable = list.devices.values.flatMap { $0 }.filter { $0.isAvailable == false }
        let unavailableSize = unavailable.reduce(Int64(0)) { $0 + ($1.dataPathSize ?? 0) }
        if !unavailable.isEmpty, unavailableSize >= 1_000_000 {
            items.append(FindingItem(
                id: "xcode.simulators/unavailable",
                title: unavailable.count == 1 ? "1 unavailable device" : "\(unavailable.count) unavailable devices",
                detail: "Their runtime is no longer installed, so they cannot boot",
                size: unavailableSize,
                command: [xcrun, "simctl", "delete", "unavailable"]
            ))
        }

        for (runtimeKey, devices) in list.devices {
            for device in devices where device.isAvailable != false {
                let title = "\(device.name) (\(runtimeName(fromKey: runtimeKey)))"
                if device.state == "Booted" {
                    protected.append(ProtectedItem(
                        id: "xcode.simulators/booted/\(device.udid)",
                        area: .xcode,
                        title: title,
                        why: "Booted right now",
                        rule: .inUse,
                        size: device.dataPathSize
                    ))
                    continue
                }
                guard let size = device.dataPathSize, size >= 200_000_000 else { continue }
                let lastUsed = device.lastUsedAt.flatMap(date(from:))
                if let lastUsed, lastUsed > context.staleCutoff { continue }
                items.append(FindingItem(
                    id: "xcode.simulators/device/\(device.udid)",
                    title: title,
                    detail: lastUsed.map { "Simulator device, last used \(context.relative($0))" } ?? "Simulator device, never used",
                    size: size,
                    command: [xcrun, "simctl", "delete", device.udid]
                ))
            }
        }
        return (items, protected)
    }

    static func runtimeItems(fromJSON json: String, xcrun: String, context: ScanContext) -> [FindingItem] {
        runtimeReport(fromJSON: json, xcrun: xcrun, context: context).items
    }

    /// Runtimes worth offering, and the newest never-used one per platform that was kept.
    static func runtimeReport(fromJSON json: String, xcrun: String, context: ScanContext) -> (items: [FindingItem], protected: [ProtectedItem]) {
        guard let runtimes = try? JSONDecoder().decode([String: SimRuntime].self, from: Data(json.utf8)) else { return ([], []) }
        let ready = runtimes.values.filter { $0.deletable == true && $0.state == "Ready" }
        var newest: [String: [Int]] = [:]
        for runtime in ready {
            let platform = runtime.platformIdentifier ?? ""
            let version = versionKey(runtime.version)
            if newest[platform].map({ $0.lexicographicallyPrecedes(version) }) ?? true { newest[platform] = version }
        }

        var items: [FindingItem] = []
        var protected: [ProtectedItem] = []
        for runtime in ready {
            guard let size = runtime.sizeBytes, size > 0 else { continue }
            let title = "\(platformName(runtime.platformIdentifier)) \(runtime.version ?? "") Simulator runtime"
            let lastUsed = runtime.lastUsedAt.flatMap(date(from:))
            if let lastUsed {
                if lastUsed > context.staleCutoff { continue }
            } else if newest[runtime.platformIdentifier ?? ""] == versionKey(runtime.version) {
                // Never used, but the newest one for its platform: most likely just installed.
                protected.append(ProtectedItem(
                    id: "xcode.simulators/newest/\(runtime.identifier)",
                    area: .xcode,
                    title: title,
                    why: "Newest \(platformName(runtime.platformIdentifier)) runtime on this Mac, kept by default",
                    rule: .defaultVersion,
                    size: size
                ))
                continue
            }
            items.append(FindingItem(
                id: "xcode.simulators/runtime/\(runtime.identifier)",
                title: title,
                detail: lastUsed.map { "Last used \(context.relative($0))" } ?? "Never used",
                size: size,
                command: [xcrun, "simctl", "runtime", "delete", runtime.identifier]
            ))
        }
        return (items, protected)
    }

    /// "com.apple.CoreSimulator.SimRuntime.iOS-17-0" -> "iOS 17.0"
    static func runtimeName(fromKey key: String) -> String {
        let parts = (key.split(separator: ".").last ?? "").split(separator: "-")
        guard let platform = parts.first else { return key }
        let version = parts.dropFirst().joined(separator: ".")
        return version.isEmpty ? String(platform) : "\(platform) \(version)"
    }

    private static func platformName(_ identifier: String?) -> String {
        switch identifier {
        case "com.apple.platform.iphonesimulator": "iOS"
        case "com.apple.platform.watchsimulator": "watchOS"
        case "com.apple.platform.appletvsimulator": "tvOS"
        case "com.apple.platform.xrsimulator": "visionOS"
        default: "Simulator"
        }
    }

    private static func versionKey(_ version: String?) -> [Int] {
        (version ?? "").split(separator: ".").compactMap { Int($0) }
    }

    private static func date(from text: String) -> Date? {
        ISO8601DateFormatter().date(from: text)
    }

    // MARK: Archives

    private static func archives(_ context: ScanContext) async -> Finding? {
        let root = context.home.appending(path: "Library/Developer/Xcode/Archives")
        var candidates: [PathCandidate] = []
        for day in Files.subdirectories(of: root) {
            for archive in Files.children(of: day) where archive.pathExtension == "xcarchive" {
                let info = Files.plist(at: archive.appending(path: "Info.plist"))
                let name = (info?["Name"] as? String) ?? archive.deletingPathExtension().lastPathComponent
                let version = (info?["ApplicationProperties"] as? [String: Any])?["CFBundleShortVersionString"] as? String
                let created = (info?["CreationDate"] as? Date) ?? Files.modificationDate(archive)
                candidates.append(PathCandidate(
                    title: version.map { "\(name) \($0)" } ?? name,
                    detail: created.map { "Archived \(context.relative($0))" } ?? "Xcode archive",
                    url: archive
                ))
            }
        }
        let items = await Sizing.items(prefix: "xcode.archives", from: candidates)
        guard !items.isEmpty else { return nil }
        return Finding(
            id: "xcode.archives",
            area: .xcode,
            aftermath: .irreplaceable,
            title: "Xcode Archives",
            summary: "\(items.count) \(items.count == 1 ? "archive" : "archives"), needed to symbolicate crashes from builds you shipped",
            explanation: "Archives hold the dSYMs for builds you shipped. Without them, crash logs from those builds cannot be symbolicated.",
            method: .trash,
            actionTarget: context.tilde(root),
            items: items
        )
    }

    // MARK: Older Xcode versions

    /// Xcode bundles in /Applications other than the one `xcode-select` points at.
    /// Switched off by the Advanced setting, which arrives here as an excluded id.
    static func oldXcodes(_ context: ScanContext) async -> (finding: Finding?, protected: [ProtectedItem]) {
        guard !context.excluded.contains(oldXcodesFindingID) else { return (nil, []) }
        return await oldXcodes(others: GuardRoots.otherXcodes(), selected: GuardRoots.selectedXcode(), context: context)
    }

    /// The same, with the bundles passed in so a test can run it on a throwaway folder.
    static func oldXcodes(others: [URL], selected: URL?, context: ScanContext,
                          minimumSize: Int64 = 1_000_000_000) async -> (finding: Finding?, protected: [ProtectedItem]) {
        guard !others.isEmpty else { return (nil, []) }
        let keptName = selected.map { "\(xcodeTitle($0)) at \($0.path) is the selected version and is kept" }
            ?? "The selected Xcode is kept"
        let candidates = others.map { bundle in
            PathCandidate(
                title: xcodeTitle(bundle),
                detail: "\(bundle.path). \(keptName)",
                url: bundle,
                hint: bundle.path
            )
        }
        let items = await Sizing.items(prefix: oldXcodesFindingID, from: candidates, minimumSize: minimumSize)
        var protected: [ProtectedItem] = []
        if let selected {
            protected.append(ProtectedItem(
                id: "\(oldXcodesFindingID)/selected",
                area: .xcode,
                title: xcodeTitle(selected),
                why: "The Xcode xcode-select points at. Never offered",
                rule: .defaultVersion,
                size: nil
            ))
        }
        guard !items.isEmpty else { return (nil, protected) }
        let finding = Finding(
            id: oldXcodesFindingID,
            area: .xcode,
            aftermath: .irreplaceable,
            title: "Older Xcode versions in Applications",
            summary: "\(items.count) \(items.count == 1 ? "copy" : "copies") of Xcode besides the selected one",
            explanation: "Whole Xcode installs that are not the one your tools use. Each is a multi-gigabyte download from Apple if a project turns out to need it. Moved to the Trash, so it can be put back.",
            method: .trash,
            actionTarget: "/Applications",
            items: items
        )
        return (finding, protected)
    }

    /// "Xcode 16.4", from the bundle's Info.plist, or the folder name when there is none.
    static func xcodeTitle(_ bundle: URL) -> String {
        let info = Files.plist(at: bundle.appending(path: "Contents/Info.plist"))
        guard let version = info?["CFBundleShortVersionString"] as? String else {
            return bundle.deletingPathExtension().lastPathComponent
        }
        return "Xcode \(version)"
    }
}
