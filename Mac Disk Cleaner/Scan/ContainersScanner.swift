//
//  ContainersScanner.swift
//  Mac Disk Cleaner
//

import Foundation

/// Docker, Colima, Lima, OrbStack and the Kubernetes tool caches.
nonisolated enum ContainersScanner {
    /// One line of `docker system df --format '{{json .}}'`.
    struct Row: Decodable {
        var type: String
        var totalCount: String
        var active: String
        var size: String?
        var reclaimable: String

        enum CodingKeys: String, CodingKey {
            case type = "Type"
            case totalCount = "TotalCount"
            case active = "Active"
            case size = "Size"
            case reclaimable = "Reclaimable"
        }
    }

    static func scan(_ context: ScanContext) async -> AreaScanResult {
        var result = AreaScanResult()
        let docker = Shell.which("docker")
        let colima = Shell.which("colima")
        let limactl = Shell.which("limactl")
        let orbstack = context.home.appending(path: ".orbstack")
        let hasOrbStack = Files.isDirectory(orbstack)

        if let finding = await CatalogScanner.finding(for: Catalog.containerCaches, context: context) {
            result.findings.append(finding)
        }

        if let docker {
            await scanDocker(docker, context: context, into: &result)
        }
        if let colima {
            await scanMachines(root: context.home.appending(path: ".colima"), marker: "colima.yaml",
                               tool: colima, toolName: "Colima", deleteVerb: "delete", id: "colima",
                               context: context, into: &result)
        }
        if let limactl {
            await scanMachines(root: context.home.appending(path: ".lima"), marker: "lima.yaml",
                               tool: limactl, toolName: "Lima", deleteVerb: "delete", id: "lima",
                               context: context, into: &result)
        }
        if hasOrbStack {
            let size = FileSizer.allocatedSize(of: orbstack)
            result.protected.append(ProtectedItem(
                id: "orbstack", area: .containers, title: "OrbStack machines and data",
                why: "OrbStack manages its own machines. Remove them from OrbStack itself",
                rule: .shownOnly, size: size
            ))
        }

        if docker == nil, colima == nil, limactl == nil, !hasOrbStack, result.findings.isEmpty {
            result.skipReason = "No container tools are installed."
        }
        return result
    }

    // MARK: Docker

    private static func scanDocker(_ docker: String, context: ScanContext, into result: inout AreaScanResult) async {
        let vmDisk = context.home.appending(path: "Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw")
        if Files.exists(vmDisk) {
            result.protected.append(ProtectedItem(
                id: "docker.vmDisk", area: .containers, title: "Docker Desktop disk image",
                why: "The disk image Docker keeps its data in. It shrinks when images and build cache are pruned",
                rule: .shownOnly, size: FileSizer.allocatedSize(of: vmDisk)
            ))
        }

        // A quick question first: a daemon that is stuck would otherwise hold the whole scan up.
        guard let ping = Shell.run(docker, ["version", "--format", "{{.Server.Version}}"], timeout: 10), ping.succeeded else {
            result.skipReason = "Docker is installed but did not answer. Open Docker, wait until it is running, then scan again."
            return
        }
        guard let output = Shell.run(docker, ["system", "df", "--format", "{{json .}}"], timeout: 90), output.succeeded else {
            result.skipReason = "Docker took too long to report its disk usage. Scan again to retry."
            return
        }
        let rows = parse(output.stdout)
        if let volumes = rows.first(where: { $0.type == "Local Volumes" }) {
            let size = bytes(from: volumes.size ?? "")
            if size > 0 {
                result.protected.append(ProtectedItem(
                    id: "docker.volumes", area: .containers,
                    title: "\(volumes.totalCount) Docker \(volumes.totalCount == "1" ? "volume" : "volumes")",
                    why: "Volumes hold data, so the app never offers them",
                    rule: .shownOnly, size: size
                ))
            }
        }
        let items = items(from: rows, docker: docker)
        guard !items.isEmpty else { return }
        result.findings.append(Finding(
            id: "docker.unused",
            area: .containers,
            tier: .review,
            title: "Docker images and build cache",
            summary: items.map { $0.title.lowercased() }.joined(separator: ", ").capitalizedFirst,
            explanation: "Images no container uses, layers kept from earlier builds, and stopped containers. Images are pulled or built again when you need them. Volumes are left alone because they can hold data.",
            method: .command,
            actionTarget: "docker image prune, docker builder prune, docker container prune",
            items: items
        ))
    }

    static func parse(_ output: String) -> [Row] {
        output.split(whereSeparator: \.isNewline).compactMap {
            try? JSONDecoder().decode(Row.self, from: Data($0.utf8))
        }
    }

    static func items(from rows: [Row], docker: String) -> [FindingItem] {
        var items: [FindingItem] = []
        for row in rows {
            let size = bytes(from: row.reclaimable)
            guard size >= 10_000_000 else { continue }
            let idle = max(0, (Int(row.totalCount) ?? 0) - (Int(row.active) ?? 0))
            switch row.type {
            case "Images":
                items.append(FindingItem(
                    id: "docker.unused/images", title: "Unused images",
                    detail: "\(idle) of \(row.totalCount) images are not used by any container", size: size,
                    command: [docker, "image", "prune", "--all", "--force"]
                ))
            case "Build Cache":
                items.append(FindingItem(
                    id: "docker.unused/buildCache", title: "Build cache",
                    detail: "Layers kept from earlier builds", size: size,
                    command: [docker, "builder", "prune", "--all", "--force"]
                ))
            case "Containers":
                items.append(FindingItem(
                    id: "docker.unused/containers", title: "Stopped containers",
                    detail: "\(idle) of \(row.totalCount) containers are not running", size: size,
                    command: [docker, "container", "prune", "--force"]
                ))
            default:
                continue
            }
        }
        return items.sorted { $0.size > $1.size }
    }

    /// "10.2GB (80%)" -> 10_200_000_000. Docker reports decimal units.
    static func bytes(from text: String) -> Int64 {
        guard let token = text.split(separator: " ").first else { return 0 }
        let number = token.prefix { $0.isNumber || $0 == "." }
        guard let value = Double(number) else { return 0 }
        let multiplier: Double = switch token.dropFirst(number.count).uppercased() {
        case "KB": 1e3
        case "MB": 1e6
        case "GB": 1e9
        case "TB": 1e12
        default: 1
        }
        return Int64((value * multiplier).rounded())
    }

    // MARK: Colima and Lima

    /// Machines a tool keeps as one folder each, offered when they have not been started for a while.
    private static func scanMachines(
        root: URL, marker: String, tool: String, toolName: String, deleteVerb: String, id: String,
        context: ScanContext, into result: inout AreaScanResult
    ) async {
        let machines = Files.subdirectories(of: root).filter { Files.exists($0.appending(path: marker)) }
        guard !machines.isEmpty else { return }
        var stale: [URL] = []
        for machine in machines {
            let changed = Files.modificationDate(machine)
            if let changed, changed > context.staleCutoff {
                result.protected.append(ProtectedItem(
                    id: "\(id).machine/\(machine.lastPathComponent)", area: .containers,
                    title: "\(toolName) machine \(machine.lastPathComponent)",
                    why: "Started \(context.relative(changed))", rule: .recentlyUsed, size: nil
                ))
            } else {
                stale.append(machine)
            }
        }
        guard !stale.isEmpty else { return }
        let sizes = await Sizing.sizes(of: stale)
        var items: [FindingItem] = []
        for machine in stale {
            let name = machine.lastPathComponent
            let changed = Files.modificationDate(machine)
            items.append(FindingItem(
                id: "\(id).machines/\(name)",
                title: "\(toolName) machine \(name)",
                detail: changed.map { "Last started \(context.relative($0))" } ?? "Virtual machine with its disk",
                size: sizes[machine] ?? 0,
                command: [tool, deleteVerb, name],
                preselected: false,
                hint: "\(URL(fileURLWithPath: tool).lastPathComponent) \(deleteVerb) \(name)"
            ))
        }
        items.sort { $0.size > $1.size }
        result.findings.append(Finding(
            id: "\(id).machines",
            area: .containers,
            tier: .review,
            title: "\(toolName) machines not started for \(context.staleDays)+ days",
            summary: "\(context.tilde(root)), \(items.count) \(items.count == 1 ? "machine" : "machines")",
            explanation: "Virtual machines \(toolName) created. Deleting one loses whatever was installed inside it; a new one is made the next time you start \(toolName).",
            method: .command,
            actionTarget: "\(URL(fileURLWithPath: tool).lastPathComponent) \(deleteVerb)",
            items: items
        ))
    }
}

private nonisolated extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
