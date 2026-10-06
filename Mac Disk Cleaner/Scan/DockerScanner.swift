//
//  DockerScanner.swift
//  Mac Disk Cleaner
//

import Foundation

nonisolated enum DockerScanner {
    /// One line of `docker system df --format '{{json .}}'`.
    struct Row: Decodable {
        var type: String
        var totalCount: String
        var active: String
        var reclaimable: String

        enum CodingKeys: String, CodingKey {
            case type = "Type"
            case totalCount = "TotalCount"
            case active = "Active"
            case reclaimable = "Reclaimable"
        }
    }

    static func scan(_ context: ScanContext) async -> AreaScanResult {
        guard let docker = Shell.which("docker") else {
            return AreaScanResult(skipReason: "Docker is not installed.")
        }
        // A quick question first: a daemon that is stuck would otherwise hold the whole scan up.
        guard let ping = Shell.run(docker, ["version", "--format", "{{.Server.Version}}"], timeout: 10), ping.succeeded else {
            return AreaScanResult(skipReason: "Docker is installed but did not answer. Open Docker, wait until it is running, then scan again.")
        }
        guard let output = Shell.run(docker, ["system", "df", "--format", "{{json .}}"], timeout: 90), output.succeeded else {
            return AreaScanResult(skipReason: "Docker took too long to report its disk usage. Scan again to retry.")
        }
        let items = items(from: parse(output.stdout), docker: docker)
        guard !items.isEmpty else { return AreaScanResult() }
        let finding = Finding(
            id: "docker.unused",
            area: .docker,
            tier: .review,
            title: "Docker images and build cache",
            summary: items.map { $0.title.lowercased() }.joined(separator: ", ").capitalizedFirst,
            explanation: "Images no container uses, layers kept from earlier builds, and stopped containers. Images are pulled or built again when you need them. Volumes are left alone because they can hold data.",
            method: .command,
            actionTarget: "docker image prune, docker builder prune, docker container prune",
            items: items
        )
        return AreaScanResult(findings: [finding])
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
}

private nonisolated extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
