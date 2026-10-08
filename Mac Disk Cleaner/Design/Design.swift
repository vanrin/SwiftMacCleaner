//
//  Design.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// The measurements, type and timings every screen is built from, so the app reads as one piece.
enum Design {
    enum Spacing {
        static let hairline: Double = 1
        static let tight: Double = 4
        static let small: Double = 8
        static let medium: Double = 12
        static let large: Double = 16
        static let xLarge: Double = 24
        /// Between the sections of a page, and between the heading of an intro and the list under it.
        static let section: Double = 32
        static let pageHorizontal: Double = 32
        static let pageVertical: Double = 24
    }

    enum Radius {
        static let control: Double = 12
        static let tile: Double = 18
        static let panel: Double = 20
    }

    enum Size {
        /// The glass disc on an intro screen.
        static let heroOrb: Double = 300
        /// The disc on the panel that reports a finished clean.
        static let compactOrb: Double = 220
        /// The round action button.
        static let orbButton: Double = 96
        /// The strip at the bottom of a screen kept clear for the round button: the button and the space around it.
        static let orbActionZone: Double = 136
        /// How far above that strip scrolling content starts to fade out.
        static let orbActionFade: Double = 36
        static let sidebar: Double = 296
        static let sidebarRow: Double = 40
        static let sidebarGlyph: Double = 24
        /// The icon in front of a line of an intro's list.
        static let featureIcon: Double = 34
        static let rowIcon: Double = 30
        static let tileIcon: Double = 44
        /// The thin bar that compares one row's size with the largest.
        static let sizeBarWidth: Double = 96
        static let sizeBarHeight: Double = 4
        /// Wide enough for "999.9 GB", so a column of sizes lines up.
        static let sizeColumn: Double = 92
        /// Wide enough for "100%".
        static let percentColumn: Double = 48
        /// The bar that shows a folder's share of its parent.
        static let shareBarWidth: Double = 140
        static let legendSwatch: Double = 10
        /// The narrowest a tile gets before the grid drops a column.
        static let tileMinimum: Double = 270
        static let tileHeight: Double = 200
        /// How wide the text of an intro may run, and how narrow it may be squeezed.
        static let introTextWidth: Double = 450
        static let introTextMinimum: Double = 360
        /// The smallest window that still fits the sidebar, the orb and the text of an intro side by side.
        static let minimumWindowWidth: Double = 1060
        static let minimumWindowHeight: Double = 680
        static let dropdownWidth: Double = 224
        static let popoverWidth: Double = 460
        static let popoverHeight: Double = 470
        static let noticeWidth: Double = 340
        static let sheetWidth: Double = 640
        static let menuBarWidth: Double = 360
    }

    enum Typeface {
        /// The large, light title of an intro or a page.
        static let heroTitle = Font.largeTitle.scaled(by: 1.85).weight(.light)
        /// The sentence under that title.
        static let heroSubtitle = Font.title
        /// A line of an intro's list.
        static let feature = Font.title2.weight(.semibold)
        /// The sentence that sums up a results screen.
        static let headline = Font.largeTitle.weight(.semibold)
        /// The figure in the middle of the orb.
        static let orbFigure = Font.largeTitle.scaled(by: 1.7).weight(.semibold)
        static let orbCaption = Font.title2
        /// The label on the round action button, and the smaller line under it.
        static let orbButton = Font.title2
        static let orbButtonDetail = Font.callout
        static let tileTitle = Font.title.weight(.semibold)
        /// Body text on a tile or a panel, a size up from the system's.
        static let tileBody = Font.title3
        static let sidebar = Font.body.scaled(by: 1.08).weight(.medium)
        static let rowTitle = Font.title3.weight(.semibold)
        /// Paths and commands.
        static let code = Font.system(.callout, design: .monospaced)
    }

    /// The interface is written in English, so it is set with English line heights. Without this, a Mac
    /// whose language list includes a tall script such as Khmer or Thai spaces every line far apart.
    static let language = Locale.Language(identifier: "en")

    enum Motion {
        /// The backdrop fading from one palette to the next.
        static let theme = Animation.smooth(duration: 0.7)
        static let press = Animation.snappy(duration: 0.15)
        /// One breath of the orb's glow while work is under way.
        static let pulse = Animation.easeInOut(duration: 1.5)
    }

    /// The see-through surfaces that sit on the backdrop. White at low strength, so the theme shows through.
    enum Surface {
        static let panelTop = Color.white.opacity(0.16)
        static let panelBottom = Color.white.opacity(0.07)
        static let panelBorder = Color.white.opacity(0.18)
        static let strongBorder = Color.white.opacity(0.6)
        /// What panels fall back to when the user asks for less transparency.
        static let solidPanel = Color.black.opacity(0.55)
        /// A recessed well inside a panel: a path, a chip, the track of a bar.
        static let well = Color.white.opacity(0.10)
        static let track = Color.white.opacity(0.14)
        static let quietButton = Color.white.opacity(0.16)
        static let hover = Color.white.opacity(0.06)
        /// The part of a ring or bar that is in use and staying.
        static let keeping = Color.white.opacity(0.3)
    }

    /// Colours with a fixed meaning, the same on every backdrop.
    enum Signal {
        static let safe = Color(hue: 0.42, saturation: 0.50, brightness: 1)
        static let review = Color(hue: 0.12, saturation: 0.65, brightness: 1)
        static let warning = Color(hue: 0.09, saturation: 0.75, brightness: 1)
    }
}
