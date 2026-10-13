//
//  ListFormat.swift
//  SwiftMacCleaner
//

import Foundation

nonisolated enum ListFormat {
    /// The names the way a sentence lists them: "Documents", "Documents and Desktop", "Downloads, Documents and Desktop".
    static func string(_ names: [String]) -> String {
        names.count < 2 ? names.joined() : names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
    }
}
