//
//  make-glyphs.swift
//  SwiftMacCleaner
//
//  Draws the app's feature glyphs and writes each one as a custom symbol, in the template format the
//  SF Symbols app exports, into an asset catalog folder.
//
//  Run from the repository root:
//      swift Tools/make-glyphs.swift SwiftMacCleaner/Assets.xcassets/Glyphs
//
//  Add `--preview <file.svg>` to also write one sheet with every glyph, for looking at them.
//

import CoreGraphics
import Foundation

/// One glyph on a 24 by 24 grid, y pointing down, as SVG path data in two tones. Solids are filled;
/// lines are stroked with round ends. An empty string leaves that part out.
struct Glyph {
    let name: String
    /// What the symbol is called in the catalog is this in front of its name: `glyph` for a feature
    /// glyph, `module` for the icon of a part of the app.
    var family = "glyph"
    /// The body: drawn in the secondary tone.
    var soft = ""
    var softLine = ""
    /// The one detail that names the glyph: drawn in the primary tone.
    var bright = ""
    var brightLine = ""
    /// A second object behind the body, for an icon made of two: drawn in the tertiary tone.
    var back = ""
    /// How wide this glyph's lines are, where that is not the usual width.
    var softWidth = Drawing.line
    var brightWidth = Drawing.line

    var symbolName: String { "\(family).\(name)" }
}

enum Drawing {
    /// The width of a line, and how far a solid's corners are rounded off, in grid units.
    static let line: CGFloat = 1.8
    static let softening: CGFloat = 0.9
}

let glyphs: [Glyph] = [
    // The parts of the app, as they stand in the lists of the opening screens
    Glyph(name: "system",
          soft: "M6.5 6h11a3 3 0 0 1 3 3v6a3 3 0 0 1 -3 3h-11a3 3 0 0 1 -3 -3v-6a3 3 0 0 1 3 -3z",
          brightLine: "M5.25 13.25h13.5M7.25 15.75h3M16.75 15.75h.01"),
    Glyph(name: "largeFiles",
          softLine: "M4.25 14.5v3a2.25 2.25 0 0 0 2.25 2.25h11a2.25 2.25 0 0 0 2.25 -2.25v-3",
          bright: "M10 4h4v6h3.25L12 15.5L6.75 10H10z"),
    Glyph(name: "apps",
          soft: "M6 4h2.75a2 2 0 0 1 2 2v2.75a2 2 0 0 1 -2 2h-2.75a2 2 0 0 1 -2 -2v-2.75a2 2 0 0 1 2 -2z"
              + "M6 13.25h2.75a2 2 0 0 1 2 2v2.75a2 2 0 0 1 -2 2h-2.75a2 2 0 0 1 -2 -2v-2.75a2 2 0 0 1 2 -2z"
              + "M15.25 13.25h2.75a2 2 0 0 1 2 2v2.75a2 2 0 0 1 -2 2h-2.75a2 2 0 0 1 -2 -2v-2.75a2 2 0 0 1 2 -2z",
          bright: "M13.2 7.4a3.4 3.4 0 1 0 6.8 0a3.4 3.4 0 1 0 -6.8 0z"),
    Glyph(name: "performance",
          soft: "M7 4h10a3 3 0 0 1 3 3v10a3 3 0 0 1 -3 3H7a3 3 0 0 1 -3 -3V7a3 3 0 0 1 3 -3z",
          bright: "M13.3 6.25L8.1 13.1h3.3l-.9 4.65L15.9 10.9h-3.3z"),

    // Developer Clean Up
    Glyph(name: "xcode",
          soft: "M13.82 8.62L15.38 10.18L5.98 19.58L4.42 18.02z",
          bright: "M9.79 7.13L12.33 4.59L19.41 11.67L16.87 14.21z"),
    Glyph(name: "projects",
          soft: "M4 7.5A1.5 1.5 0 0 1 5.5 6h3.6l2 2h7.4A1.5 1.5 0 0 1 20 9.5v8a1.5 1.5 0 0 1 -1.5 1.5h-13A1.5 1.5 0 0 1 4 17.5z",
          bright: "M5.5 11h13a1.5 1.5 0 0 1 1.5 1.5v5a1.5 1.5 0 0 1 -1.5 1.5h-13a1.5 1.5 0 0 1 -1.5 -1.5v-5a1.5 1.5 0 0 1 1.5 -1.5z"),
    Glyph(name: "android",
          soft: "M8 8h8a3.5 3.5 0 0 1 3.5 3.5v4a3.5 3.5 0 0 1 -3.5 3.5h-8a3.5 3.5 0 0 1 -3.5 -3.5v-4a3.5 3.5 0 0 1 3.5 -3.5z",
          brightLine: "M12 7.6V5.4M12 4.3h.01M9.3 11.9v1M14.7 11.9v1M10 16h4"),
    Glyph(name: "containers",
          soft: "M5 12.5h4.5a1.5 1.5 0 0 1 1.5 1.5v3a1.5 1.5 0 0 1 -1.5 1.5h-4.5a1.5 1.5 0 0 1 -1.5 -1.5v-3a1.5 1.5 0 0 1 1.5 -1.5z"
              + "M14.5 12.5h4.5a1.5 1.5 0 0 1 1.5 1.5v3a1.5 1.5 0 0 1 -1.5 1.5h-4.5a1.5 1.5 0 0 1 -1.5 -1.5v-3a1.5 1.5 0 0 1 1.5 -1.5z",
          bright: "M9.75 4.5h4.5a1.5 1.5 0 0 1 1.5 1.5v3a1.5 1.5 0 0 1 -1.5 1.5h-4.5a1.5 1.5 0 0 1 -1.5 -1.5v-3a1.5 1.5 0 0 1 1.5 -1.5z"),
    Glyph(name: "packageCaches",
          soft: "M12 4l6.93 4v8L12 20l-6.93 -4V8z",
          bright: "M12 4l6.93 4L12 12L5.07 8z",
          brightLine: "M12 12v7.2"),
    Glyph(name: "toolchains",
          soft: "M6.5 5h11a3 3 0 0 1 3 3v8a3 3 0 0 1 -3 3h-11a3 3 0 0 1 -3 -3v-8a3 3 0 0 1 3 -3z",
          brightLine: "M7.5 9.5l3 2.5l-3 2.5M12.75 14.75h3.75"),
    Glyph(name: "ides",
          soft: "M6.5 4.5h11a3 3 0 0 1 3 3v9a3 3 0 0 1 -3 3h-11a3 3 0 0 1 -3 -3v-9a3 3 0 0 1 3 -3z",
          bright: "M3.5 7.5a3 3 0 0 1 3 -3h2v15h-2a3 3 0 0 1 -3 -3z",
          brightLine: "M11.75 9h3M13.25 12h3.75M11.75 15h4.5"),
    Glyph(name: "models",
          softLine: "M12 13.4V6M12 13.4L5.8 17.4M12 13.4l6.2 4",
          bright: "M10.1 6a1.9 1.9 0 1 0 3.8 0a1.9 1.9 0 1 0 -3.8 0z"
              + "M3.9 17.4a1.9 1.9 0 1 0 3.8 0a1.9 1.9 0 1 0 -3.8 0z"
              + "M16.3 17.4a1.9 1.9 0 1 0 3.8 0a1.9 1.9 0 1 0 -3.8 0z"
              + "M9.6 13.4a2.4 2.4 0 1 0 4.8 0a2.4 2.4 0 1 0 -4.8 0z"),

    // System Clean Up
    Glyph(name: "cachesLogs",
          soft: "M8 3.5h8a2.5 2.5 0 0 1 2.5 2.5v12a2.5 2.5 0 0 1 -2.5 2.5h-8a2.5 2.5 0 0 1 -2.5 -2.5v-12a2.5 2.5 0 0 1 2.5 -2.5z",
          brightLine: "M9 8.25h6M9 12h6M9 15.75h3"),
    Glyph(name: "trash",
          soft: "M6.5 9h11l-.9 9.6a1.6 1.6 0 0 1 -1.6 1.4H9a1.6 1.6 0 0 1 -1.6 -1.4z",
          brightLine: "M4.5 6.5h15M9.75 6.25V5a1 1 0 0 1 1 -1h2.5a1 1 0 0 1 1 1v1.25M10.25 12.25v4.5M13.75 12.25v4.5"),
    Glyph(name: "snapshots",
          soft: "M7.25 12a5.25 5.25 0 1 0 10.5 0a5.25 5.25 0 1 0 -10.5 0z",
          brightLine: "M4.25 5.25v4.5h4.5M5.7 15.17A7.5 7.5 0 1 0 6.93 6.98L4.25 9.75M12.5 8.5V12l2.5 1.6"),

    // Applications
    Glyph(name: "uninstaller",
          soft: "M8.5 4h7a4.5 4.5 0 0 1 4.5 4.5v7a4.5 4.5 0 0 1 -4.5 4.5h-7a4.5 4.5 0 0 1 -4.5 -4.5v-7a4.5 4.5 0 0 1 4.5 -4.5z",
          brightLine: "M9 9l6 6M15 9l-6 6"),
    Glyph(name: "updater",
          soft: "M3.75 12a8.25 8.25 0 1 0 16.5 0a8.25 8.25 0 1 0 -16.5 0z",
          brightLine: "M12 16.25V8M8.5 11.25L12 7.75l3.5 3.5"),
    Glyph(name: "unused",
          soft: "M19.5 14.2A8 8 0 1 1 9.8 4.5a7.2 7.2 0 0 0 9.7 9.7z",
          brightLine: "M15 4.5h3.5L15 8.5h3.5"),
    Glyph(name: "leftovers",
          soft: "M8 4h4v8h8v4a4 4 0 0 1 -4 4H8a4 4 0 0 1 -4 -4V8a4 4 0 0 1 4 -4z",
          bright: "M15.75 5.25h1.25a1 1 0 0 1 1 1v1.25a1 1 0 0 1 -1 1h-1.25a1 1 0 0 1 -1 -1v-1.25a1 1 0 0 1 1 -1z",
          brightLine: "M19.75 9.75h.01"),
    Glyph(name: "installers",
          soft: "M3.75 12a8.25 8.25 0 1 0 16.5 0a8.25 8.25 0 1 0 -16.5 0z",
          brightLine: "M10.25 12a1.75 1.75 0 1 0 3.5 0a1.75 1.75 0 1 0 -3.5 0zM6.58 11.05A5.5 5.5 0 0 1 11.05 6.58"),

    // Performance
    Glyph(name: "maintenance",
          softLine: "M13.9 10.1L5.25 18.75",
          bright: "M15.16 12.39A3.9 3.9 0 1 0 11.62 8.84L14.65 9.35z"),
    Glyph(name: "loginItems",
          softLine: "M8.25 7.5a6.25 6.25 0 1 0 7.5 0",
          brightLine: "M12 4v7.5"),
    Glyph(name: "backgroundItems",
          soft: "M12 3.5c2.3 1.7 3.5 4.3 3.5 7.6v4.4h-7v-4.4c0 -3.3 1.2 -5.9 3.5 -7.6z"
              + "M8.5 11.5L5.25 14.75v3.25l3.25 -1.75zM15.5 11.5l3.25 3.25v3.25l-3.25 -1.75z",
          bright: "M10.6 9.4a1.4 1.4 0 1 0 2.8 0a1.4 1.4 0 1 0 -2.8 0zM10.25 16.5h3.5L12 20.5z"),

    // Menu bar readings
    Glyph(name: "cpu",
          soft: "M8.75 6.25h6.5a2.5 2.5 0 0 1 2.5 2.5v6.5a2.5 2.5 0 0 1 -2.5 2.5h-6.5a2.5 2.5 0 0 1 -2.5 -2.5v-6.5a2.5 2.5 0 0 1 2.5 -2.5z",
          softLine: "M9.5 3.25v2M14.5 3.25v2M9.5 18.75v2M14.5 18.75v2M3.25 9.5h2M3.25 14.5h2M18.75 9.5h2M18.75 14.5h2",
          bright: "M10.25 9.5h3.5a.75 .75 0 0 1 .75 .75v3.5a.75 .75 0 0 1 -.75 .75h-3.5a.75 .75 0 0 1 -.75 -.75v-3.5a.75 .75 0 0 1 .75 -.75z"),
    Glyph(name: "memory",
          soft: "M5 6.5h14a2 2 0 0 1 2 2v5.5a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-5.5a2 2 0 0 1 2 -2z",
          softLine: "M6.5 16.75v2.25M10.17 16.75v2.25M13.83 16.75v2.25M17.5 16.75v2.25",
          brightLine: "M8 9.75v3M12 9.75v3M16 9.75v3"),
    Glyph(name: "battery",
          soft: "M5.5 7.75h10.5a2.5 2.5 0 0 1 2.5 2.5v3.5a2.5 2.5 0 0 1 -2.5 2.5h-10.5a2.5 2.5 0 0 1 -2.5 -2.5v-3.5a2.5 2.5 0 0 1 2.5 -2.5z",
          softLine: "M21 10.75v2.5",
          bright: "M6 10.5h7.5v3h-7.5z"),
]

/// The icon of each part of the app, as an object: its body (the secondary tone), the one mark on
/// its face (primary) and, where the icon is two objects, the one behind (tertiary). The app draws
/// the body in a gradient with a soft copy of it just below; see `ModuleIcon`. A mark always lies
/// on the body, since it is drawn in white.
let modules: [Glyph] = [
    Glyph(name: "overview", family: "module",
          soft: "M6.5 5h11a2 2 0 0 1 2 2v6.5a2 2 0 0 1 -2 2h-11a2 2 0 0 1 -2 -2v-6.5a2 2 0 0 1 2 -2z"
              + "M2.75 17.8h18.5a.45 .45 0 0 1 0 .9h-18.5a.45 .45 0 0 1 0 -.9z",
          bright: "M12 6.75c.4 2 1.5 3.1 3.5 3.5c-2 .4 -3.1 1.5 -3.5 3.5c-.4 -2 -1.5 -3.1 -3.5 -3.5c2 -.4 3.1 -1.5 3.5 -3.5z"),
    Glyph(name: "system", family: "module",
          soft: "M6.5 6h11a3 3 0 0 1 3 3v6a3 3 0 0 1 -3 3h-11a3 3 0 0 1 -3 -3v-6a3 3 0 0 1 3 -3z",
          brightLine: "M7.25 14.75h3.5M16.75 14.75h.01",
          brightWidth: 1.7),
    Glyph(name: "developer", family: "module",
          softLine: "M8.75 7.75L4.5 12l4.25 4.25M15.25 7.75L19.5 12l-4.25 4.25M13.4 5.5l-2.8 13",
          softWidth: 2.3),
    Glyph(name: "largeFiles", family: "module",
          soft: "M10 4h4v6h3.25L12 15.5L6.75 10H10z"
              + "M3.7 14.2v3.3a2.8 2.8 0 0 0 2.8 2.8h11a2.8 2.8 0 0 0 2.8 -2.8v-3.3h-1.1v3.3a1.7 1.7 0 0 1 -1.7 1.7h-11a1.7 1.7 0 0 1 -1.7 -1.7v-3.3z"),
    Glyph(name: "protection", family: "module",
          soft: "M12 3.25l7 2.6v5.4c0 4.5 -2.9 7.9 -7 9.5c-4.1 -1.6 -7 -5 -7 -9.5v-5.4z",
          brightLine: "M8.6 11.9l2.45 2.45l4.35 -4.7",
          brightWidth: 1.9),
    Glyph(name: "performance", family: "module",
          soft: "M7 4h10a3 3 0 0 1 3 3v10a3 3 0 0 1 -3 3H7a3 3 0 0 1 -3 -3V7a3 3 0 0 1 3 -3z",
          bright: "M13.3 6.25L8.1 13.1h3.3l-.9 4.65L15.9 10.9h-3.3z"),
    Glyph(name: "apps", family: "module",
          soft: "M6 4h2.75a2 2 0 0 1 2 2v2.75a2 2 0 0 1 -2 2h-2.75a2 2 0 0 1 -2 -2v-2.75a2 2 0 0 1 2 -2z"
              + "M6 13.25h2.75a2 2 0 0 1 2 2v2.75a2 2 0 0 1 -2 2h-2.75a2 2 0 0 1 -2 -2v-2.75a2 2 0 0 1 2 -2z"
              + "M15.25 13.25h2.75a2 2 0 0 1 2 2v2.75a2 2 0 0 1 -2 2h-2.75a2 2 0 0 1 -2 -2v-2.75a2 2 0 0 1 2 -2z"
              + "M13.2 7.4a3.4 3.4 0 1 0 6.8 0a3.4 3.4 0 1 0 -6.8 0z"),
    Glyph(name: "space", family: "module",
          soft: "M6 4h4a2 2 0 0 1 2 2v12a2 2 0 0 1 -2 2h-4a2 2 0 0 1 -2 -2v-12a2 2 0 0 1 2 -2z"
              + "M16.25 4h2a1.75 1.75 0 0 1 1.75 1.75v5.5a1.75 1.75 0 0 1 -1.75 1.75h-2a1.75 1.75 0 0 1 -1.75 -1.75v-5.5a1.75 1.75 0 0 1 1.75 -1.75z"
              + "M16.25 15h2a1.75 1.75 0 0 1 1.75 1.75v1.5a1.75 1.75 0 0 1 -1.75 1.75h-2a1.75 1.75 0 0 1 -1.75 -1.75v-1.5a1.75 1.75 0 0 1 1.75 -1.75z"),
    Glyph(name: "duplicates", family: "module",
          soft: "M11.75 8.25H18a2 2 0 0 1 2 2v8a2 2 0 0 1 -2 2h-6.25a2 2 0 0 1 -2 -2v-8a2 2 0 0 1 2 -2z",
          back: "M6 3.75h6.25a2 2 0 0 1 2 2v8a2 2 0 0 1 -2 2H6a2 2 0 0 1 -2 -2v-8a2 2 0 0 1 2 -2z"),
    Glyph(name: "settings", family: "module",
          soft: "M10.43 5.69L10.79 3.49L13.21 3.49L13.57 5.69L15.35 6.43L17.16 5.12L18.88 6.84L17.57 8.65L18.31 10.43"
              + "L20.51 10.79L20.51 13.21L18.31 13.57L17.57 15.35L18.88 17.16L17.16 18.88L15.35 17.57L13.57 18.31"
              + "L13.21 20.51L10.79 20.51L10.43 18.31L8.65 17.57L6.84 18.88L5.12 17.16L6.43 15.35L5.69 13.57"
              + "L3.49 13.21L3.49 10.79L5.69 10.43L6.43 8.65L5.12 6.84L6.84 5.12L8.65 6.43z",
          brightLine: "M9.25 12a2.75 2.75 0 1 0 5.5 0a2.75 2.75 0 1 0 -5.5 0z"),
]

// MARK: - SVG path data to CGPath

/// Reads the subset of SVG path data the glyphs are written in: M L H V C A Z in both cases, with
/// circular arcs only.
func path(fromSVG data: String) -> CGPath {
    let result = CGMutablePath()
    let pattern = #/[MmLlHhVvCcAaZz]|-?(?:\d+\.?\d*|\.\d+)/#
    var tokens = data.matches(of: pattern).map { String($0.output) }[...]
    var command: Character = "M"
    var current = CGPoint.zero
    var start = CGPoint.zero

    func number() -> CGFloat {
        guard let token = tokens.popFirst(), let value = Double(token) else {
            fatalError("Expected a number in: \(data)")
        }
        return value
    }

    while let token = tokens.first {
        if let letter = token.first, letter.isLetter {
            command = letter
            tokens.removeFirst()
        }
        let isRelative = command.isLowercase
        let origin = isRelative ? current : .zero
        switch command.uppercased() {
        case "M":
            current = CGPoint(x: origin.x + number(), y: origin.y + number())
            start = current
            result.move(to: current)
            // Pairs that follow a move without a letter are lines.
            command = isRelative ? "l" : "L"
        case "L":
            current = CGPoint(x: origin.x + number(), y: origin.y + number())
            result.addLine(to: current)
        case "H":
            current.x = origin.x + number()
            result.addLine(to: current)
        case "V":
            current.y = origin.y + number()
            result.addLine(to: current)
        case "C":
            let first = CGPoint(x: origin.x + number(), y: origin.y + number())
            let second = CGPoint(x: origin.x + number(), y: origin.y + number())
            current = CGPoint(x: origin.x + number(), y: origin.y + number())
            result.addCurve(to: current, control1: first, control2: second)
        case "A":
            var radius = number()
            _ = number()
            _ = number()
            let isLarge = number() != 0
            let isSweep = number() != 0
            let end = CGPoint(x: origin.x + number(), y: origin.y + number())
            let halfChord = hypot(end.x - current.x, end.y - current.y) / 2
            radius = max(radius, halfChord)
            let rise = (radius * radius - halfChord * halfChord).squareRoot()
            let side: CGFloat = isLarge != isSweep ? 1 : -1
            let center = CGPoint(
                x: (current.x + end.x) / 2 - side * rise * (end.y - current.y) / (2 * halfChord),
                y: (current.y + end.y) / 2 + side * rise * (end.x - current.x) / (2 * halfChord)
            )
            result.addArc(center: center, radius: radius,
                          startAngle: atan2(current.y - center.y, current.x - center.x),
                          endAngle: atan2(end.y - center.y, end.x - center.x),
                          clockwise: !isSweep)
            current = end
        case "Z":
            result.closeSubpath()
            current = start
        default:
            fatalError("Unsupported command \(command) in: \(data)")
        }
    }
    return result
}

// MARK: - Outlining

/// One tone of a glyph as a single filled outline: its solids with their corners rounded off, and
/// its lines given their width. A symbol template holds fills only.
func outline(solid: String, line: String, width: CGFloat = Drawing.line) -> CGPath {
    var result: CGPath = CGMutablePath()
    if !solid.isEmpty {
        let shape = path(fromSVG: solid)
        let edge = shape.copy(strokingWithWidth: Drawing.softening, lineCap: .round, lineJoin: .round, miterLimit: 4)
        result = result.union(shape.normalized(using: .winding)).union(edge.normalized(using: .winding))
    }
    if !line.isEmpty {
        let stroke = path(fromSVG: line)
            .copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 4)
        result = result.union(stroke.normalized(using: .winding))
    }
    return result
}

func svgData(for path: CGPath, transform: CGAffineTransform) -> String {
    var transform = transform
    guard let placed = path.copy(using: &transform) else { return "" }
    func text(_ point: CGPoint) -> String {
        String(format: "%.3f %.3f", point.x, point.y)
    }
    var parts: [String] = []
    placed.applyWithBlock { element in
        let points = element.pointee.points
        switch element.pointee.type {
        case .moveToPoint: parts.append("M\(text(points[0]))")
        case .addLineToPoint: parts.append("L\(text(points[0]))")
        case .addQuadCurveToPoint: parts.append("Q\(text(points[0])) \(text(points[1]))")
        case .addCurveToPoint: parts.append("C\(text(points[0])) \(text(points[1])) \(text(points[2]))")
        case .closeSubpath: parts.append("Z")
        @unknown default: break
        }
    }
    return parts.joined()
}

// MARK: - The symbol template

/// Where things sit in a template, which is typeset at 100 points: the baseline of the small row, the
/// cap height above it, and the left margin of each of the three weights a template is drawn in.
enum Template {
    static let baseline: CGFloat = 696
    static let capHeight: CGFloat = 70.459
    /// The glyph's 24 units fill 100, which is the size of a full-height symbol such as `circle`.
    static let width: CGFloat = 100
    static let scale = width / 24
    static let weights: [(name: String, left: CGFloat)] = [("Black", 2860), ("Regular", 1400), ("Ultralight", 510)]

    /// Places the grid in a weight's own coordinates: its left margin at 0, the baseline at 0, and the
    /// middle of the grid at half the cap height, as the system's symbols are.
    static let placement = CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: 0, ty: -capHeight / 2 - 12 * scale)
}

/// A glyph's tones from the back to the front, each as one outline, with the level it takes in a
/// hierarchy and the grey the SF Symbols app shows that level in. A tone with nothing in it is left out.
func layers(of glyph: Glyph, placed transform: CGAffineTransform) -> [(level: String, grey: String, data: String)] {
    [
        ("tertiary", "#D8D8D8", outline(solid: glyph.back, line: "")),
        ("secondary", "#8E8E8E", outline(solid: glyph.soft, line: glyph.softLine, width: glyph.softWidth)),
        ("primary", "#212121", outline(solid: glyph.bright, line: glyph.brightLine, width: glyph.brightWidth)),
    ]
    .map { (level: $0.0, grey: $0.1, data: svgData(for: $0.2, transform: transform)) }
    .filter { !$0.data.isEmpty }
}

func template(for glyph: Glyph) -> String {
    let layers = layers(of: glyph, placed: Template.placement)
    let guide = "fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;"
    let margin = "fill:none;stroke:#00AEEF;stroke-width:0.5;opacity:1.0;"
    let note = "stroke:none;fill:black;font-family:sans-serif;font-size:13;text-anchor:end;"

    var lines = [
        #"<?xml version="1.0" encoding="UTF-8"?>"#,
        #"<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">"#,
        #"<svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="3300" height="2200">"#,
        " <!--Written by Tools/make-glyphs.swift. Change the drawing there, not here.-->",
        " <style>" + layers.indices.map { ".monochrome-\($0) {fill:#000000}" }.joined(separator: "\n"),
        "",
        layers.indices.map { ".multicolor-\($0):tintColor {fill:#007AFF}" }.joined(separator: "\n"),
        "",
        layers.enumerated().map { ".hierarchical-\($0):\($1.level) {fill:\($1.grey)}" }.joined(separator: "\n"),
        "</style>",
        #" <g id="Notes">"#,
        #"  <rect height="2200" id="artboard" style="fill:white;opacity:1" width="3300" x="0" y="0"/>"#,
        #"  <text id="template-version" style="\#(note)" transform="matrix(1 0 0 1 3036 1933)">Template v.4.0</text>"#,
        #"  <text style="\#(note)" transform="matrix(1 0 0 1 3036 1951)">Requires Xcode 14 or greater</text>"#,
        #"  <text id="descriptive-name" style="\#(note)" transform="matrix(1 0 0 1 3036 1969)">\#(glyph.symbolName)</text>"#,
        #"  <text style="\#(note)" transform="matrix(1 0 0 1 3036 1987)">Typeset at 100 points</text>"#,
        " </g>",
        #" <g id="Guides">"#,
    ]
    for (row, top) in [("S", Template.baseline), ("M", Template.baseline + 430), ("L", Template.baseline + 860)] {
        lines.append(#"  <line id="Baseline-\#(row)" style="\#(guide)" x1="263" x2="3036" y1="\#(top)" y2="\#(top)"/>"#)
        lines.append(#"  <line id="Capline-\#(row)" style="\#(guide)" x1="263" x2="3036" y1="\#(top - Template.capHeight)" y2="\#(top - Template.capHeight)"/>"#)
    }
    for weight in Template.weights.reversed() {
        for (side, x) in [("left", weight.left), ("right", weight.left + Template.width)] {
            lines.append(#"  <line id="\#(side)-margin-\#(weight.name)-S" style="\#(margin)" x1="\#(x)" x2="\#(x)" y1="600.785" y2="720.121"/>"#)
        }
    }
    lines.append(" </g>")
    lines.append(#" <g id="Symbols">"#)
    // The same drawing stands in for all three weights, so the glyph has one weight however bold the text is.
    for weight in Template.weights {
        lines.append(#"  <g id="\#(weight.name)-S" transform="matrix(1 0 0 1 \#(weight.left) \#(Template.baseline))">"#)
        for (index, layer) in layers.enumerated() {
            lines.append(#"   <path class="monochrome-\#(index) multicolor-\#(index):tintColor hierarchical-\#(index):\#(layer.level)" d="\#(layer.data)"/>"#)
        }
        lines.append("  </g>")
    }
    lines.append(" </g>")
    lines.append("</svg>")
    return lines.joined(separator: "\n") + "\n"
}

/// Every glyph and module icon on one sheet, white on a dark ground with the body at half strength
/// and whatever stands behind it fainter still.
func previewSheet() -> String {
    let columns = 8
    let cell: CGFloat = 96
    let everything = glyphs + modules
    let rows = (everything.count + columns - 1) / columns
    var lines = [
        #"<svg xmlns="http://www.w3.org/2000/svg" width="\#(CGFloat(columns) * cell)" height="\#(CGFloat(rows) * cell)">"#,
        #"<rect width="100%" height="100%" fill="rgb(36,20,82)"/>"#,
    ]
    let strength = ["tertiary": 0.3, "secondary": 0.5, "primary": 1]
    for (index, glyph) in everything.enumerated() {
        let place = CGAffineTransform(a: 3, b: 0, c: 0, d: 3,
                                      tx: CGFloat(index % columns) * cell + 12, ty: CGFloat(index / columns) * cell + 12)
        for layer in layers(of: glyph, placed: place) {
            lines.append(#"<path fill="white" opacity="\#(strength[layer.level] ?? 1)" d="\#(layer.data)"/>"#)
        }
    }
    lines.append("</svg>")
    return lines.joined(separator: "\n") + "\n"
}

// MARK: - Writing

let arguments = CommandLine.arguments.dropFirst()
guard let folder = arguments.first, !folder.hasPrefix("--") else {
    fatalError("Usage: swift make-glyphs.swift <asset catalog folder> [--preview <file.svg>]")
}
let root = URL(fileURLWithPath: folder)
let files = FileManager.default
let info = #"{"author" : "xcode", "version" : 1}"#

try files.createDirectory(at: root, withIntermediateDirectories: true)
try "{\n  \"info\" : \(info)\n}\n".write(to: root.appending(path: "Contents.json"), atomically: true, encoding: .utf8)
for glyph in glyphs + modules {
    let name = glyph.symbolName
    let set = root.appending(path: "\(name).symbolset")
    try files.createDirectory(at: set, withIntermediateDirectories: true)
    let contents = """
    {
      "info" : \(info),
      "symbols" : [
        {
          "filename" : "\(name).svg",
          "idiom" : "universal"
        }
      ]
    }

    """
    try contents.write(to: set.appending(path: "Contents.json"), atomically: true, encoding: .utf8)
    try template(for: glyph).write(to: set.appending(path: "\(name).svg"), atomically: true, encoding: .utf8)
}
if let flag = arguments.firstIndex(of: "--preview"), arguments.indices.contains(flag + 1) {
    try previewSheet().write(toFile: arguments[flag + 1], atomically: true, encoding: .utf8)
}
print("Wrote \(glyphs.count + modules.count) symbols to \(root.path)")
