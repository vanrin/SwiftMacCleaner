//
//  MemoryDefaults.swift
//  SwiftMacCleanerTests
//

import Foundation

/// A settings store that lives in memory alone. A test that builds its `AppSettings` on one sees the
/// app as it is on a Mac that has changed nothing, whatever this Mac's own settings say, and leaves
/// no file behind in ~/Library/Preferences.
///
/// Every typed read and write of `UserDefaults` goes through the three methods overridden here.
final class MemoryDefaults: UserDefaults {
    private var values: [String: Any] = [:]

    /// The name is never written to: it only keeps this store apart from the app's own, should a
    /// read or write ever get past the overrides.
    convenience init() {
        self.init(suiteName: "mdc-memory-\(UUID().uuidString)")!
    }

    override func object(forKey defaultName: String) -> Any? { values[defaultName] }

    override func set(_ value: Any?, forKey defaultName: String) { values[defaultName] = value }

    override func removeObject(forKey defaultName: String) { values[defaultName] = nil }
}
