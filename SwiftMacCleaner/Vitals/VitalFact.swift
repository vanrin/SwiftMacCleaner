//
//  VitalFact.swift
//  SwiftMacCleaner
//

import Foundation

/// One figure in a reading's details, with the sentence that says what it means.
nonisolated struct VitalFact: Identifiable, Equatable, Sendable {
    var title: String
    var value: String
    var detail: String

    var id: String { title }
}
