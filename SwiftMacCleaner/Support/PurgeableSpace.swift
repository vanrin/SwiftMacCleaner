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
    /// How many times the disk is read while it hands the reservation back, and how long between
    /// readings: a minute and a half in all before the wait is given up.
    static let handBackReadings = 360
    static let handBackPause: useconds_t = 250_000
    /// Two readings this close count as the same. Other programs write all the time.
    static let steady: Int64 = 64_000_000

    struct Outcome: Sendable {
        var before: DiskInfo
        var after: DiskInfo
        var reserved: Int64
        /// False when the disk still counted the reservation as used when the wait for it ran out.
        var handedBack = true

        /// What the disk gained for files that matter, which is the only number worth promising.
        var gained: Int64 { max(0, after.free - before.free) }
    }

    /// Reserves and releases. Nil when the reservation file could not be made.
    static func free(home: URL) -> Outcome? {
        let before = DiskInfo.current(for: home)
        guard before.purgeable >= worthIt else { return Outcome(before: before, after: before, reserved: 0) }
        // Everything macOS says it could make available, less the floor. The reservation past what is
        // free right now is what makes it evict.
        return reserve(max(0, before.free + before.purgeable - floor), home: home, before: before)
    }

    /// Reserves `target` bytes in one file, lets them go, and waits until the disk has them back.
    /// Nil when the file could not be made.
    static func reserve(_ target: Int64, home: URL, before: DiskInfo) -> Outcome? {
        let folder = home.appending(path: "Library/Caches").appending(path: CleanLog.folderName)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "reserve-\(UUID().uuidString)")
        let descriptor = open(file.path, O_RDWR | O_CREAT | O_EXCL, 0o600)
        guard descriptor >= 0 else { return nil }
        // Unlinked while open: the space goes back once the process ends, however it ends.
        unlink(file.path)

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
        let after = settled(freeBefore: before.free, reserved: reserved) { DiskInfo.current(for: home) }
        return Outcome(before: before, after: after.disk, reserved: reserved, handedBack: after.isBack)
    }

    /// The disk once a reservation it held has come back. Closing the file only starts that: macOS
    /// returns the room in its own time, about a second for 50 GB with room to spare, and after this
    /// task's own reservation a reading taken more than a second later still counted nearly all of it
    /// as used. That reading made a run that freed 6 GB say free space fell from 56 GB to 2.6 GB.
    ///
    /// Waits until most of the reservation is back and the reading has stopped rising. `isBack` is
    /// false when the readings ran out first. `pause` and `measure` are stood in for by the tests.
    static func settled(
        freeBefore: Int64, reserved: Int64, readings: Int = handBackReadings,
        pause: () -> Void = { usleep(handBackPause) }, measure: () -> DiskInfo
    ) -> (disk: DiskInfo, isBack: Bool) {
        var disk = measure()
        guard reserved > 0 else { return (disk, true) }
        // Other programs write meanwhile, so the mark is well short of where the disk started. A
        // reservation too small to reach the mark is back long before the reading has held still.
        let mark = freeBefore - max(reserved / 2, 1_000_000_000)
        var unchanged = 0
        for _ in 1..<max(readings, 1) {
            if disk.free >= mark, unchanged >= 3 { return (disk, true) }
            pause()
            let next = measure()
            unchanged = abs(next.free - disk.free) < steady ? unchanged + 1 : 0
            disk = next
        }
        return (disk, disk.free >= mark && unchanged >= 3)
    }

    /// The command-line entry: prints what happened and says whether it worked through the exit status.
    static func main() -> Int32 {
        guard let outcome = free(home: FileManager.default.homeDirectoryForCurrentUser) else {
            FileHandle.standardError.write(Data("Could not make the reservation file in ~/Library/Caches\n".utf8))
            return 1
        }
        print("Purgeable before: \(ByteFormat.string(outcome.before.purgeable)), after: \(ByteFormat.string(outcome.after.purgeable)). "
              + "Reserved \(ByteFormat.string(outcome.reserved)); the disk gained \(ByteFormat.string(outcome.gained)).")
        guard outcome.handedBack else {
            FileHandle.standardError.write(Data("macOS has not handed the reserved space back yet, so free space reads low until it does\n".utf8))
            return 1
        }
        return 0
    }
}
