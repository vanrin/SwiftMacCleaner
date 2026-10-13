//
//  QuietInk.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The quieter of the app's two inks, for text that steps back. SwiftUI's own `.secondary` draws text
/// in the primary style at half strength, which is too faint to read on the pale ground.
nonisolated struct QuietInk: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> Color {
        // On the one dark surface, the Mac's display, the quiet ink is a paler white.
        environment.colorScheme == .dark ? .white.opacity(0.78) : Design.Ink.secondary
    }
}

extension ShapeStyle where Self == QuietInk {
    static var quiet: QuietInk { QuietInk() }
}
