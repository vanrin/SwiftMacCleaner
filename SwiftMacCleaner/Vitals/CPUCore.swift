//
//  CPUCore.swift
//  SwiftMacCleaner
//

import Foundation

/// One of the processor's cores and how busy it is.
nonisolated struct CPUCore: Identifiable, Equatable, Sendable {
    /// Apple's chips have fast cores and frugal ones. An Intel Mac's are all alike.
    enum Kind: CaseIterable, Sendable {
        case performance, efficiency, plain

        /// The line under this kind's bars in the CPU details.
        func caption(count: Int) -> String {
            switch self {
            case .performance: "\(count) performance core\(count == 1 ? "" : "s")"
            case .efficiency: "\(count) efficiency"
            case .plain: "\(count) core\(count == 1 ? "" : "s")"
            }
        }
    }

    /// The core's number, as the kernel counts them.
    var id: Int
    var kind: Kind
    /// From 0 to 1.
    var load: Double
}
