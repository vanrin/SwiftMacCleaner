//
//  AppIconView.swift
//  SwiftMacCleaner
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// An app's own icon, the one Finder shows. The name beside it carries the meaning.
struct AppIconView: View {
    let url: URL
    var size = Design.Size.appIcon

    var body: some View {
        Image(nsImage: AppIcons.icon(for: url))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Icons already read from disk, so a list of apps does not read each one again as it scrolls.
enum AppIcons {
    private static var icons: [String: NSImage] = [:]

    static func icon(for url: URL) -> NSImage {
        if let icon = icons[url.path] { return icon }
        // A bundle that is not there, as in the demo, gets the icon macOS gives an app without one.
        let icon = Files.exists(url) ? NSWorkspace.shared.icon(forFile: url.path) : NSWorkspace.shared.icon(for: .applicationBundle)
        icons[url.path] = icon
        return icon
    }
}
