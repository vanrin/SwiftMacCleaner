//
//  ModelsScanner.swift
//  Mac Disk Cleaner
//

import Foundation

/// Models and datasets fetched from a hub, which are large and never ticked for the user.
nonisolated enum ModelsScanner {
    static let huggingFaceHub = ".cache/huggingface/hub"
    static let ollamaFolder = ".ollama/models"

    static func scan(_ context: ScanContext) async -> AreaScanResult {
        var result = AreaScanResult()
        let group = Catalog.modelDownloads
        let ollama = Shell.which("ollama")

        var candidates: [PathCandidate] = []
        for location in group.locations {
            if location.path == huggingFaceHub { continue }
            if location.path == ollamaFolder, ollama != nil { continue }
            candidates.append(PathCandidate(title: location.title, detail: location.detail,
                                            url: context.home.appending(path: location.path),
                                            preselected: location.preselected, hint: location.hint))
        }
        candidates += huggingFaceCandidates(context: context, protected: &result.protected)

        let items = await Sizing.items(prefix: group.id, from: candidates, minimumSize: group.minimumSize)
        if !items.isEmpty {
            result.findings.append(Finding(
                id: group.id,
                area: group.area,
                tier: group.tier,
                title: group.title,
                summary: group.summary(of: items),
                explanation: group.explanation,
                method: group.method,
                actionTarget: group.actionTarget,
                items: items
            ))
        }

        if let ollama, let output = Shell.run(ollama, ["list"], timeout: 20), output.succeeded {
            let models = ollamaItems(fromList: output.stdout, ollama: ollama)
            if !models.isEmpty {
                result.findings.append(Finding(
                    id: "models.ollama",
                    area: .models,
                    tier: .review,
                    title: "Ollama models",
                    summary: "\(models.count) \(models.count == 1 ? "model" : "models") pulled with ollama",
                    explanation: "Models Ollama has pulled. Each one is downloaded again with ollama pull when you need it. Nothing here is ticked for you.",
                    method: .command,
                    actionTarget: "ollama rm",
                    items: models
                ))
            }
        }

        if result.findings.isEmpty, result.protected.isEmpty {
            result.skipReason = "No model or dataset downloads found."
        }
        return result
    }

    /// One candidate per repository in the Hugging Face hub cache, leaving recently used ones alone.
    private static func huggingFaceCandidates(context: ScanContext, protected: inout [ProtectedItem]) -> [PathCandidate] {
        let hub = context.home.appending(path: huggingFaceHub)
        var candidates: [PathCandidate] = []
        for folder in Files.subdirectories(of: hub) {
            guard let repo = huggingFaceName(folderName: folder.lastPathComponent) else { continue }
            let changed = Files.modificationDate(folder)
            let kind = folder.lastPathComponent.hasPrefix("datasets--") ? "dataset" : "model"
            if let changed, changed > context.staleCutoff {
                protected.append(ProtectedItem(
                    id: "models.huggingface/\(folder.lastPathComponent)", area: .models,
                    title: "\(repo) (Hugging Face \(kind))",
                    why: "Used \(context.relative(changed))", rule: .recentlyUsed, size: nil
                ))
                continue
            }
            candidates.append(PathCandidate(
                title: repo,
                detail: "Hugging Face \(kind), last used " + (changed.map(context.relative) ?? "a while ago"),
                url: folder,
                preselected: false,
                hint: context.tilde(folder)
            ))
        }
        return candidates
    }

    /// "models--meta-llama--Llama-3" -> "meta-llama/Llama-3". Nil for a folder that is not a repository.
    static func huggingFaceName(folderName: String) -> String? {
        for prefix in ["models--", "datasets--", "spaces--"] where folderName.hasPrefix(prefix) {
            let rest = folderName.dropFirst(prefix.count)
            let parts = rest.components(separatedBy: "--")
            guard !rest.isEmpty, parts.allSatisfy({ !$0.isEmpty }) else { return nil }
            return parts.joined(separator: "/")
        }
        return nil
    }

    /// Parses `ollama list`: a header, then "NAME  ID  SIZE  MODIFIED" with columns split by two or more spaces.
    static func ollamaItems(fromList output: String, ollama: String) -> [FindingItem] {
        var items: [FindingItem] = []
        for line in output.split(whereSeparator: \.isNewline).dropFirst() {
            let columns = line.split(whereSeparator: { $0 == "\t" }).flatMap { $0.components(separatedBy: "  ") }
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard columns.count >= 3 else { continue }
            let name = columns[0]
            let size = bytes(from: columns[2])
            let modified = columns.count >= 4 ? columns[3] : ""
            items.append(FindingItem(
                id: "models.ollama/\(name)",
                title: name,
                detail: "Pulled again with ollama pull \(name). " + (modified.isEmpty ? "" : "Modified \(modified)"),
                size: size,
                command: [ollama, "rm", name],
                preselected: false,
                hint: "ollama rm \(name)"
            ))
        }
        return items.sorted { $0.size > $1.size }
    }

    /// "4.7 GB" -> 4_700_000_000. Ollama reports decimal units with a space before the unit.
    static func bytes(from text: String) -> Int64 {
        let parts = text.split(separator: " ")
        guard let number = parts.first, let value = Double(number) else { return 0 }
        let unit = parts.dropFirst().first.map { $0.uppercased() } ?? ""
        let multiplier: Double = switch unit {
        case "KB": 1e3
        case "MB": 1e6
        case "GB": 1e9
        case "TB": 1e12
        default: 1
        }
        return Int64((value * multiplier).rounded())
    }
}
