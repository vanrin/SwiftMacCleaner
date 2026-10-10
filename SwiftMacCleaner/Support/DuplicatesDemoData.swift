//
//  DuplicatesDemoData.swift
//  SwiftMacCleaner
//

#if DEBUG
import Foundation

/// Made-up duplicates for looking at the Duplicates screens without reading or touching a real file.
/// Launch with `--demo duplicates`, followed by `intro`, `scanning`, `results`, `ticked`, `review`,
/// `removing` or `done`. `--demo duplicates scan <folder>` runs the real scan instead, which only reads.
nonisolated enum DuplicatesDemoData {
    private static let home = "/Users/demo/"

    /// One copy. `clone` names the data it points at; copies with the same one share their space.
    private static func file(_ path: String, megabytes: Double, clone: UInt64, clones: Int = 1, daysAgo: Double,
                             locked: String? = nil) -> DuplicateFile {
        let size = Int64(megabytes * 1e6)
        let date = Date().addingTimeInterval(-daysAgo * 86_400)
        return DuplicateFile(
            url: URL(fileURLWithPath: home + path), size: size, allocated: size, created: date, modified: date,
            storage: FileStorage(cloneID: clone, cloneCount: clones, privateSize: clones > 1 ? 0 : size),
            lockedReason: locked, inode: clone, modifiedNanoseconds: 0
        )
    }

    private static func group(_ id: String, _ kind: DuplicateKind, megabytes: Double, _ files: [DuplicateFile]) -> DuplicateGroup {
        DuplicateGroup(id: id, kind: kind, size: Int64(megabytes * 1e6), files: files)
    }

    static func groups() -> [DuplicateGroup] {
        let groups = [
            group("timelapse", .videos, megabytes: 1_840, [
                file("Movies/Exports/Harbour timelapse.mov", megabytes: 1_840, clone: 1, daysAgo: 210),
                file("Desktop/Harbour timelapse.mov", megabytes: 1_840, clone: 2, daysAgo: 208),
                file("Downloads/Harbour timelapse (1).mov", megabytes: 1_840, clone: 3, daysAgo: 95),
            ]),
            group("install", .archives, megabytes: 612, [
                file("Documents/Installers/Harbor-4.31.0-arm64.dmg", megabytes: 612, clone: 4, daysAgo: 60),
                file("Downloads/Harbor-4.31.0-arm64.dmg", megabytes: 612, clone: 5, daysAgo: 21),
            ]),
            // Finder's Duplicate makes a clone: a second file on the same data.
            group("deck", .documents, megabytes: 148, [
                file("Documents/Talks/Autumn review.key", megabytes: 148, clone: 6, clones: 2, daysAgo: 34),
                file("Documents/Talks/Autumn review copy.key", megabytes: 148, clone: 6, clones: 2, daysAgo: 30),
                file("Downloads/Autumn review.key", megabytes: 148, clone: 7, daysAgo: 12),
            ]),
            group("album", .music, megabytes: 96, [
                file("Music/Mixes/Night drive.flac", megabytes: 96, clone: 8, daysAgo: 400),
                file("Downloads/Night drive.flac", megabytes: 96, clone: 9, daysAgo: 399),
            ]),
            group("return", .documents, megabytes: 18, [
                file("Documents/Taxes/2025 return.pdf", megabytes: 18, clone: 10, daysAgo: 150,
                     locked: "It is on your Never Suggest list"),
                file("Desktop/2025 return.pdf", megabytes: 18, clone: 11, daysAgo: 149),
                file("Downloads/2025 return (2).pdf", megabytes: 18, clone: 12, daysAgo: 140),
            ]),
            group("panorama", .images, megabytes: 42, [
                file("Pictures/Trips/Lisbon/panorama.tiff", megabytes: 42, clone: 13, daysAgo: 300),
                file("Desktop/panorama.tiff", megabytes: 42, clone: 14, daysAgo: 280),
            ]),
            group("screenshot", .images, megabytes: 6.2, [
                file("Desktop/Screenshots/Dashboard.png", megabytes: 6.2, clone: 15, clones: 2, daysAgo: 9),
                file("Desktop/Screenshots/Dashboard copy.png", megabytes: 6.2, clone: 15, clones: 2, daysAgo: 9),
            ]),
            group("portrait", .images, megabytes: 4.8, [
                file("Pictures/Portraits/IMG_2291.heic", megabytes: 4.8, clone: 16, daysAgo: 500),
                file("Documents/Print/IMG_2291.heic", megabytes: 4.8, clone: 17, daysAgo: 420),
                file("Downloads/IMG_2291.heic", megabytes: 4.8, clone: 18, daysAgo: 418),
            ]),
        ]
        return groups.sorted { ($0.reclaimable, $0.size) > ($1.reclaimable, $1.size) }
    }

    /// What a removal would report: every step done, every file in the Trash.
    static func outcome(for plan: CleanPlan) -> CleanOutcome {
        let steps = plan.steps.map { step in
            StepOutcome(
                id: step.id, title: step.title, method: step.method, size: step.size,
                cleanedItemIDs: step.operations.map(\.itemID), failures: [],
                trashed: step.operations.compactMap { operation in
                    guard case .trash(let url) = operation.kind else { return nil }
                    return TrashedItem(original: url, inTrash: URL(fileURLWithPath: "/Users/demo/.Trash/\(url.lastPathComponent)"),
                                       size: operation.size)
                }
            )
        }
        let free = DiskInfo.current().free
        return CleanOutcome(steps: steps, freeBefore: free, freeAfter: free,
                            trashedSize: steps.flatMap(\.trashed).reduce(0) { $0 + $1.size },
                            duration: 3, logURL: nil, started: Date())
    }
}
#endif
