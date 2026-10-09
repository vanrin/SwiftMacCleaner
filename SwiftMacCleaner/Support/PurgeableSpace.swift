//
//  PurgeableSpace.swift
//  SwiftMacCleaner
//

import Foundation

/// Makes macOS give back the space it holds in reserve. macOS evicts purgeable content only when a
/// write needs the room, so this reserves the disk's free space for a moment, in one file, and lets
/// it go again. Nothing is written to the file and nothing is read; the reservation is the whole trick.
///
/// Run as `SwiftMacCleaner --free-purgeable` by the Performance task, so it is a step like any other.
nonisolated enum PurgeableSpace {
    /// What is left free at the tightest moment, so nothing else on the Mac runs out of room meanwhile.
    static let floor: Int64 = 1_500_000_000
    static let chunk: Int64 = 1_000_000_000
    static let smallChunk: Int64 = 128_000_000
    /// Less than this is not worth a minute of the disk's time.
    static let worthIt: Int64 = 100_000_000

    struct Outcome: Sendable {
        var before: DiskInfo
        var after: DiskInfo
        var reserved: Int64

        /// What the disk gained for files that matter, which is the only number worth promising.
        var gained: Int64 { max(0, after.free - before.free) }
    }

    /// Reserves and releases. Nil when the reservation file could not be made.
    static func free(home: URL) -> Outcome? {
        let before = DiskInfo.current(for: home)
        guard before.purgeable >= worthIt else { return Outcome(before: before, after: before, reserved: 0) }

        let folder = home.appending(path: "Library/Caches").appending(path: CleanLog.folderName)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "reserve-\(UUID().uuidString)")
        let descriptor = open(file.path, O_RDWR | O_CREAT | O_EXCL, 0o600)
        guard descriptor >= 0 else { return nil }
        // Unlinked while open: the space goes back the moment the process ends, however it ends.
        unlink(file.path)
        defer { close(descriptor) }

        // Everything macOS says it could make available, less the floor. The reservation past what is
        // free right now is what makes it evict.
        let target = max(0, before.free + before.purgeable - floor)
        var reserved: Int64 = 0
        var size = chunk
        while reserved < target {
            let wanted = min(size, target - reserved)
            var store = fstore_t(fst_flags: UInt32(F_ALLOCATEALL), fst_posmode: F_PEOFPOSMODE, fst_offset: 0,
                                 fst_length: off_t(wanted), fst_bytesalloc: 0)
            if fcntl(descriptor, F_PREALLOCATE, &store) == 0 {
                reserved += Int64(store.fst_bytesalloc)
            } else if size > smallChunk {
                size = smallChunk
            } else {
                break
            }
        }
        // A moment for macOS to finish evicting before the room is handed back.
        sleep(1)
        close(descriptor)
        sleep(1)
        return Outcome(before: before, after: DiskInfo.current(for: home), reserved: reserved)
    }

    /// The command-line entry: prints what happened and says whether it worked through the exit status.
    static func main() -> Int32 {
        guard let outcome = free(home: FileManager.default.homeDirectoryForCurrentUser) else {
            FileHandle.standardError.write(Data("Could not make the reservation file in ~/Library/Caches\n".utf8))
            return 1
        }
        print("Purgeable before: \(ByteFormat.string(outcome.before.purgeable)), after: \(ByteFormat.string(outcome.after.purgeable)). "
              + "Reserved \(ByteFormat.string(outcome.reserved)); the disk gained \(ByteFormat.string(outcome.gained)).")
        return 0
    }
}
