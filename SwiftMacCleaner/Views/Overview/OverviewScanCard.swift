//
//  OverviewScanCard.swift
//  SwiftMacCleaner
//

import SwiftUI

/// One part of the app while the overview scans. The part shown at work stands large in a wash of
/// its own colour and says what it is doing. One that is scanning beside it shows its icon, dimmed.
/// One that is done shows what it found, laid out as its tile will be once the scan is over.
struct OverviewScanCard: View {
    @Environment(AppModel.self) private var model
    let part: SidebarItem
    /// The one card that says what its scan is doing right now.
    let isFeatured: Bool

    private enum Role {
        case featured, scanning, done
    }

    var body: some View {
        let role: Role = isFeatured ? .featured : model.isScanning(part) ? .scanning : .done
        GlassPanel(cornerRadius: Design.Radius.tile) {
            GeometryReader { proxy in
                ZStack {
                    switch role {
                    case .featured: featured(in: proxy.size)
                    case .scanning: scanning(in: proxy.size)
                    case .done: done(in: proxy.size)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .animation(Design.Motion.iconTint, value: role)
            }
            .padding(Design.Spacing.large)
            .background {
                // The colour of the part at work, rising from the foot of its card.
                RoundedRectangle(cornerRadius: Design.Radius.tile)
                    .fill(LinearGradient(colors: [part.theme.lens.opacity(0), part.theme.lens.opacity(0.34)],
                                         startPoint: .top, endPoint: .bottom))
                    .opacity(role == .featured ? 1 : 0)
                    .animation(Design.Motion.scanCards, value: role)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// What the scan is doing, the part's icon, and what it is on right now.
    private func featured(in size: CGSize) -> some View {
        VStack(spacing: Design.Spacing.small) {
            Text(model.scanTitle(of: part))
                .font(Design.Typeface.heroSubtitle)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            // As large as the card allows, up to a point: the icon is what the card is.
            ModuleIcon(symbol: part.icon, theme: part.theme,
                       size: min(Design.Size.scanIcon, max(size.height * 0.42, Design.Size.sidebarGlyph)), depth: Design.Depth.hero)
            Spacer(minLength: 0)
            Text(model.scanDetail(of: part))
                .font(.callout)
                .foregroundStyle(.quiet)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    /// The part's name, its icon held back, and a word that it is being scanned too.
    private func scanning(in size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: Design.Spacing.tight) {
            name(in: size)
            ModuleIcon(symbol: part.icon, theme: part.theme,
                       size: min(Design.Size.waitingIcon, max(size.height - 64, Design.Size.sidebarGlyph)), depth: Design.Depth.rest)
                .opacity(0.4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text("Scanning")
                .font(Design.Typeface.tileBody)
                .foregroundStyle(.quiet)
                .lineLimit(1)
        }
        .transition(.opacity)
    }

    /// What the part found: its name and icon at the top, its figure at the foot, as on its tile.
    /// A narrow card stands the icon over the name, so that a name of one long word keeps its line.
    private func done(in size: CGSize) -> some View {
        let figure = model.overviewFigure(of: part)
        return VStack(alignment: .leading, spacing: Design.Spacing.tight) {
            if size.width < Design.Size.scanCardNarrow {
                ModuleIcon(symbol: part.icon, theme: part.theme, size: Design.Size.rowIcon, depth: Design.Depth.tile)
                name(in: size)
            } else {
                HStack(alignment: .top, spacing: Design.Spacing.small) {
                    name(in: size)
                    Spacer(minLength: 0)
                    ModuleIcon(symbol: part.icon, theme: part.theme, size: Design.Size.tileIcon, depth: Design.Depth.tile)
                }
            }
            Spacer(minLength: 0)
            Text(figure.value)
                .font(Design.Typeface.tileTitle)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(figure.caption)
                .font(Design.Typeface.tileBody)
                .foregroundStyle(.quiet)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .transition(.opacity)
    }

    /// The part's name, on two lines where the card has the height for them and the figure under it.
    private func name(in size: CGSize) -> some View {
        Text(part.title)
            .font(Design.Typeface.rowTitle)
            .lineLimit(size.height < Design.Size.scanCardShort ? 1 : 2)
            .minimumScaleFactor(0.8)
            .fixedSize(horizontal: false, vertical: true)
    }
}
