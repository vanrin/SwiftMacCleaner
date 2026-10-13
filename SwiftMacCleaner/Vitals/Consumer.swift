//
//  Consumer.swift
//  SwiftMacCleaner
//

import Foundation

/// An app, or a program that belongs to none, with what all of its processes use together.
nonisolated struct Consumer: Identifiable, Equatable, Sendable {
    /// What a list of consumers is ranked by.
    enum Measure: Sendable {
        case cpu, memory
    }

    /// How many a list shows.
    static let listLength = 5
    /// Folders that hold macOS itself.
    private static let systemFolders = ["/System/", "/usr/", "/bin/", "/sbin/", "/Library/Apple/"]
    private static let finder = "com.apple.finder"

    /// The app's bundle, or the program itself when it belongs to no app.
    var id: String
    var name: String
    /// Share of one core, out of 100, so an app busy on two cores reads 200. Nil until two counts can be compared.
    var cpu: Double?
    var memory: Int64
    /// Set when this is an app the user can ask to quit.
    var bundleID: String?
    /// Part of macOS, which the list says in place of a Quit button.
    var isSystem: Bool

    /// Where the icon comes from.
    var url: URL { URL(fileURLWithPath: id) }
    var canQuit: Bool { bundleID != nil }

    func text(for measure: Measure) -> String {
        switch measure {
        case .cpu: VitalFormat.percent((cpu ?? 0) / 100, decimals: 1)
        case .memory: VitalFormat.memory(memory, decimals: 2)
        }
    }

    /// The programs gathered into the apps they belong to.
    ///
    /// A helper lives inside its app's bundle, so the path says whose it is: the innermost bundle
    /// on the way that is a running app, or else the outermost bundle. A program outside any bundle
    /// stands alone under its own name.
    /// - Parameters:
    ///   - earlier: The same programs as counted before, by number, to measure processor time against.
    ///   - elapsed: The seconds between the two counts.
    ///   - own: This app's bundle identifier, which gets no Quit button.
    ///   - name: What a program that belongs to no running app goes by, when something better than
    ///     its file name is known.
    static func grouped(_ usages: [ProcessUsage], since earlier: [pid_t: ProcessUsage] = [:], elapsed: TimeInterval = 0,
                        apps: [RunningApp], own: String? = nil, name: (String) -> String? = { _ in nil }) -> [Consumer] {
        let appsByPath = Dictionary(apps.map { ($0.path, $0) }) { first, _ in first }
        var consumers: [String: Consumer] = [:]
        for usage in usages {
            let bundles = bundles(in: usage.path)
            let app = bundles.reversed().lazy.compactMap { appsByPath[$0] }.first
            let key = app?.path ?? bundles.first ?? usage.path
            var consumer = consumers[key] ?? {
                let isSystem = systemFolders.contains(where: key.hasPrefix)
                let quits = app.map { ($0.isRegular || !isSystem) && $0.bundleID != finder && $0.bundleID != own } ?? false
                return Consumer(id: key, name: app?.name ?? name(key) ?? fileName(of: key),
                                memory: 0, bundleID: quits ? app?.bundleID : nil, isSystem: isSystem && !quits)
            }()
            consumer.memory += usage.memory
            if elapsed > 0, let before = earlier[usage.pid], before.startedAt == usage.startedAt, usage.cpuTime >= before.cpuTime {
                consumer.cpu = (consumer.cpu ?? 0) + Double(usage.cpuTime - before.cpuTime) / (elapsed * 1_000_000_000) * 100
            }
            consumers[key] = consumer
        }
        return Array(consumers.values)
    }

    /// A bundle's name without its ending, or a program's file name as it stands: a program may
    /// well have dots in its name.
    static func fileName(of path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.pathExtension == "app" ? url.deletingPathExtension().lastPathComponent : url.lastPathComponent
    }

    /// The name a program's own bundle gives it, when it sits in one that is not an app: an XPC
    /// service calls itself "Virtual Machine Service" where its file is named after its identifier.
    static func bundleName(ofProgramAt path: String) -> String? {
        // …/Name.xpc/Contents/MacOS/program
        let bundle = URL(fileURLWithPath: path).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard ["xpc", "appex"].contains(bundle.pathExtension), let info = Bundle(url: bundle)?.infoDictionary else { return nil }
        return (info["CFBundleDisplayName"] ?? info["CFBundleName"]) as? String
    }

    /// Every app bundle on the way to `path`, the outermost first.
    static func bundles(in path: String) -> [String] {
        var found: [String] = []
        var prefix = ""
        for part in path.split(separator: "/") {
            prefix += "/" + part
            if part.hasSuffix(".app") { found.append(prefix) }
        }
        return found
    }
}

nonisolated extension Sequence<Consumer> {
    /// The few that use the most, the largest first. Ones that have yet to be measured, or use
    /// next to nothing, are left out.
    func top(by measure: Consumer.Measure) -> [Consumer] {
        let ranked: [Consumer] = switch measure {
        case .cpu: filter { ($0.cpu ?? 0) >= 0.05 }.sorted { ($0.cpu ?? 0, $1.name) > ($1.cpu ?? 0, $0.name) }
        case .memory: filter { $0.memory > 0 }.sorted { ($0.memory, $1.name) > ($1.memory, $0.name) }
        }
        return Array(ranked.prefix(Consumer.listLength))
    }
}
