//
//  Design.swift
//  SwiftMacCleaner
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
        /// One core's bar in the CPU details.
        static let bar: Double = 4
        /// The details that stand beside the menu bar popover, rounded like the popover's own window.
        static let menuBarPanel: Double = 14
    }

    enum Size {
        /// The Mac on the opening screen: as wide as the room beside the text allows, between these two.
        static let heroMac: Double = 400
        static let heroMacMinimum: Double = 288
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
        /// The sidebar folded down to its glyphs.
        static let sidebarRail: Double = 84
        /// A sidebar entry is as tall as its chip on the rail is wide, so the chip there is square.
        static let sidebarRow: Double = 48
        static let sidebarGlyph: Double = 28
        /// A choice in a manager's column.
        static let columnRow: Double = 40
        /// A glyph at the head of a line in a list, and the smallest a part's icon is drawn.
        static let listGlyph: Double = 24
        /// A part's icon on the glass disc of its opening screen.
        static let heroIcon: Double = 140
        /// How far from the middle of the disc the pointer has its full pull on that icon.
        static let heroReach: Double = 280
        /// A part's icon on its card while the overview scans: on the card at work, and dimmed on one
        /// that is not the one shown at work. Each is the most it gets; a small card has a smaller one.
        static let scanIcon: Double = 168
        static let waitingIcon: Double = 72
        /// Under this width inside, a card that is done has no room for its name and its icon side by side.
        static let scanCardNarrow: Double = 170
        /// Under this height inside, a card has room for one line of its name over what it says.
        static let scanCardShort: Double = 130
        /// The dot on a rail glyph whose part has something to do.
        static let sidebarDot: Double = 7
        /// The icon in front of a line of an intro's list.
        static let featureIcon: Double = 34
        static let rowIcon: Double = 30
        static let tileIcon: Double = 44
        /// How much of a lens's width the grid of its glyph takes up.
        static let lensGlyphShare: Double = 0.6
        /// An app's own icon in a list of apps.
        static let appIcon: Double = 36
        /// The column beside a list of apps that holds the parts of the manager and the filters.
        static let filterColumn: Double = 228
        /// The column of System Clean Up's manager, whose area names run longer than the parts of the other managers.
        static let areaColumn: Double = 272
        /// A search field above a list, and how far it may be squeezed in a narrow window.
        static let searchField: Double = 220
        static let searchFieldMinimum: Double = 120
        /// The thin bar that compares one row's size with the largest.
        static let sizeBarWidth: Double = 96
        static let sizeBarHeight: Double = 4
        /// The bar on the Mac's display that splits the disk into used, purgeable and free.
        static let usageBarHeight: Double = 8
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
        /// How far the details of a reading stand from the menu bar popover they open beside.
        static let menuBarGap: Double = 10
        /// The ring on a tile of the menu bar popover, and the tile's height.
        static let vitalRing: Double = 56
        static let vitalRingLine: Double = 6
        static let vitalTile: Double = 120
        /// The ring at the top of a reading's details.
        static let detailRing: Double = 120
        static let detailRingLine: Double = 12
        /// The bar beside a figure in the CPU details that says which part of the ring it is.
        static let legendBarWidth: Double = 4
        static let legendBarHeight: Double = 28
        /// One core's bar in the CPU details: as wide as this when there is room, never thinner than the minimum.
        static let coreBarWidth: Double = 14
        static let coreBarMinimum: Double = 3
        static let coreBarHeight: Double = 44
        static let coreBarSpacing: Double = 5
        /// A row of the apps that use the most, its icon, and the room kept for a Quit button.
        static let consumerRow: Double = 32
        static let consumerIcon: Double = 24
        static let consumerAction: Double = 52
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
        /// A sidebar glyph. At the small scale its grid is drawn as large as this font, which fills the glyph's frame.
        static let sidebarGlyph = Font.title.scaled(by: 1.1)
        static let rowTitle = Font.title3.weight(.semibold)
        /// The figure in the ring of a menu bar tile, and in the larger ring of a reading's details.
        static let vitalFigure = Font.body.weight(.semibold)
        static let detailFigure = Font.largeTitle.weight(.semibold)
        /// The name of a reading at the top of its details, and the word that sums it up.
        static let detailTitle = Font.title2.weight(.semibold)
        /// Paths and commands.
        static let code = Font.system(.callout, design: .monospaced)
    }

    /// How far the soft copy of a part's icon sits below its face, in units of the icon's 24-unit grid,
    /// so the depth grows with the icon. Kept shallow: the copy is a hint of thickness, not a side.
    enum Depth {
        static let rest: Double = 1.2
        static let hover: Double = 1.7
        static let pressed: Double = 0.4
        static let selected: Double = 1.4
        /// On a tile of the overview, where the icon wears its own colours at all times.
        static let tile: Double = 1.4
        /// On the glass disc of an opening screen: standing, and with the pointer near.
        static let hero: Double = 1.6
        static let heroNear: Double = 1.9
        /// How strong the copy is. It comes out paler than the face, never darker.
        static let copyOpacity: Double = 0.42
        /// How far the icon on an opening screen turns towards the pointer, in degrees.
        static let turn: Double = 11
    }

    /// The interface is written in English, so it is set with English line heights. Without this, a Mac
    /// whose language list includes a tall script such as Khmer or Thai spaces every line far apart.
    static let language = Locale.Language(identifier: "en")

    enum Motion {
        static let press = Animation.snappy(duration: 0.15)
        /// The sidebar folding down to a rail and opening out again, and its names fading with it.
        static let sidebar = Animation.snappy(duration: 0.3)
        static let sidebarNames = Animation.easeOut(duration: 0.2)
        /// The label beside a rail entry coming and going with the pointer.
        static let sidebarHint = Animation.easeOut(duration: 0.12)
        /// One breath of the orb's glow while work is under way.
        static let pulse = Animation.easeInOut(duration: 1.5)
        /// A part's icon lifting off its copy under the pointer, and settling back.
        static let iconLift = Animation.spring(duration: 0.26, bounce: 0.35)
        /// The icon taking its own colours, and giving them up.
        static let iconTint = Animation.easeOut(duration: 0.18)
        /// The icon on an opening screen turning to follow the pointer.
        static let iconTurn = Animation.easeOut(duration: 0.16)
        /// Half of one breath of an icon whose part is being scanned.
        static let iconBusy = Animation.easeInOut(duration: 0.6)
        /// The cards of the overview's scan making room for the next one at work.
        static let scanCards = Animation.smooth(duration: 0.45)
    }

    /// Text, and the solid dark tone of what stands out on the ground: the chosen tick, a main pill.
    nonisolated enum Ink {
        static let primary = Color(hue: 0.622, saturation: 0.441, brightness: 0.133)
        static let secondary = Color(hue: 0.623, saturation: 0.265, brightness: 0.400)
        /// Chevrons and separators.
        static let tertiary = Color(hue: 0.625, saturation: 0.187, brightness: 0.588)
    }

    /// The window's ground: pale silver, lighter towards the top left, the same behind every part of the app.
    enum Ground {
        static let top = Color(hue: 0.611, saturation: 0.024, brightness: 0.976)
        static let mid = Color(hue: 0.606, saturation: 0.046, brightness: 0.937)
        static let deep = Color(hue: 0.611, saturation: 0.066, brightness: 0.886)
        /// The light behind a screen's artwork.
        static let bloom = Color.white
        /// What something raised casts on the ground. Used at low strength.
        static let shadow = Color(hue: 0.625, saturation: 0.500, brightness: 0.314)
    }

    /// The glass that sits on the ground: white for what is raised, ink at low strength for what is recessed.
    enum Surface {
        static let panelTop = Color.white.opacity(0.85)
        static let panelBottom = Color.white.opacity(0.48)
        static let panelBorder = Color.white.opacity(0.95)
        /// The edge of a surface when the user asks for more contrast.
        static let strongBorder = Ink.primary.opacity(0.55)
        /// The bright edge of something round and raised: the action button, the glass disc, a lens.
        static let rim = Color.white.opacity(0.95)
        /// The shadow under a panel.
        static let shadow = Ground.shadow.opacity(0.12)
        /// What panels fall back to when the user asks for less transparency.
        static let solidPanel = Color.white.opacity(0.94)
        /// A recessed well inside a panel: a path, a chip, the track of a bar.
        static let well = Ink.primary.opacity(0.06)
        static let track = Ink.primary.opacity(0.10)
        static let quietButton = Ink.primary.opacity(0.08)
        /// The chosen row of a list: a chip of the same glass as a panel.
        static let selected = Color.white.opacity(0.8)
        static let hover = Ink.primary.opacity(0.04)
        /// A sidebar entry under the pointer: the chip of the chosen entry, fainter.
        static let hoverChip = Color.white.opacity(0.6)
        /// The part of a ring or bar that is in use and staying.
        static let keeping = Ink.primary.opacity(0.24)
        /// The second part of a ring or bar whose first part is in the accent.
        static let secondShare = Ink.primary.opacity(0.72)
    }

    /// The round action button: graphite, the same in every part of the app.
    enum Action {
        static let light = Color(hue: 0.627, saturation: 0.264, brightness: 0.565)
        static let body = Color(hue: 0.625, saturation: 0.364, brightness: 0.259)
        static let shade = Ink.primary
    }

    /// The colours of the picture the app shares with its icon: the swift, the Mac and its display.
    /// The swift is the one warm colour in the app.
    enum Brand {
        /// The swift, from the wing in the light to the wing in the shade.
        static let swift = Gradient(colors: [
            Color(hue: 0.10, saturation: 0.72, brightness: 1),
            Color(hue: 0.06, saturation: 0.82, brightness: 1),
            Color(hue: 0.016, saturation: 0.84, brightness: 0.93),
        ])
        static let aluminium = Color(hue: 0.609, saturation: 0.113, brightness: 0.796)
        static let aluminiumShade = Color(hue: 0.615, saturation: 0.170, brightness: 0.671)
        /// The line round the lid and the base, which keeps the pale metal apart from the pale ground.
        static let edge = Color(hue: 0.625, saturation: 0.400, brightness: 0.392).opacity(0.3)
        static let bezel = Color(hue: 0.625, saturation: 0.615, brightness: 0.051)
        static let screenLight = Color(hue: 0.625, saturation: 0.300, brightness: 0.260)
        static let screenDeep = Color(hue: 0.622, saturation: 0.400, brightness: 0.070)
        /// The trail the swift leaves across the display.
        static let bloom = Color(hue: 0.615, saturation: 0.116, brightness: 0.878)
        /// What is written on the display, which stays dark in the light window, and the empty part of a bar there.
        static let screenText = Color.white
        static let screenTrack = Color.white.opacity(0.2)
    }

    /// Colours with a fixed meaning, the same on every screen. Dark enough to read as text on the ground.
    enum Signal {
        static let safe = Color(hue: 0.429, saturation: 0.943, brightness: 0.412)
        static let review = Color(hue: 0.112, saturation: 1, brightness: 0.478)
        static let warning = Color(hue: 0, saturation: 0.818, brightness: 0.690)
    }
}
