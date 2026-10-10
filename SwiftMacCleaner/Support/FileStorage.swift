//
//  FileStorage.swift
//  SwiftMacCleaner
//

import Foundation

/// What the disk says about where a file's data lives. On APFS a copy made by Finder is a clone: a
/// second file that points at the same data, and takes up next to nothing until one of them changes.
nonisolated struct FileStorage: Sendable, Hashable {
    /// Names the data the file points at. Files with the same one are clones of each other, alike to the last byte.
    var cloneID: UInt64
    /// How many files on the disk point at that data, this one included.
    var cloneCount: Int
    /// What deleting this file alone would free at once: the part of it no clone and no snapshot holds on to.
    var privateSize: Int64

    /// A file that shares its data with no other, for a disk that does not say.
    static func unshared(inode: UInt64, allocated: Int64) -> FileStorage {
        FileStorage(cloneID: inode, cloneCount: 1, privateSize: allocated)
    }

    /// Asks the disk about one file, without following a link. Nil when the disk does not keep these
    /// figures, as one that is not APFS.
    static func read(_ path: String) -> FileStorage? {
        let wanted = attrgroup_t(ATTR_CMNEXT_PRIVATESIZE | ATTR_CMNEXT_CLONEID | ATTR_CMNEXT_CLONE_REFCNT)
        var list = attrlist()
        list.bitmapcount = UInt16(ATTR_BIT_MAP_COUNT)
        list.commonattr = attrgroup_t(ATTR_CMN_RETURNED_ATTRS)
        list.forkattr = wanted
        var buffer = [UInt8](repeating: 0, count: 64)
        guard getattrlist(path, &list, &buffer, buffer.count, UInt32(FSOPT_ATTR_CMN_EXTENDED | FSOPT_NOFOLLOW)) == 0 else { return nil }
        return buffer.withUnsafeBytes { raw in
            // A length, the set of what came back, then the values in the order of their bits.
            let returned = raw.loadUnaligned(fromByteOffset: 4, as: attribute_set_t.self)
            guard returned.forkattr & wanted == wanted else { return nil }
            let values = 4 + MemoryLayout<attribute_set_t>.size
            return FileStorage(
                cloneID: raw.loadUnaligned(fromByteOffset: values + 8, as: UInt64.self),
                cloneCount: max(1, Int(raw.loadUnaligned(fromByteOffset: values + 16, as: UInt32.self))),
                privateSize: raw.loadUnaligned(fromByteOffset: values, as: Int64.self)
            )
        }
    }
}
