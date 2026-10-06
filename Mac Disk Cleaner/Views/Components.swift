//
//  Components.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// "Safe", "Review" or "Careful", always spelled out so colour is never the only signal.
struct TierBadge: View {
    let tier: SafetyTier

    var body: some View {
        Text(tier.label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(foreground)
            .background(background, in: .rect(cornerRadius: 5))
    }

    private var foreground: Color {
        switch tier {
        case .safe: Color.accentColor.mix(with: .primary, by: 0.25)
        case .review: Color.orange.mix(with: .primary, by: 0.45)
        case .careful: Color(nsColor: .windowBackgroundColor)
        }
    }

    private var background: Color {
        switch tier {
        case .safe: Color.accentColor.opacity(0.15)
        case .review: Color.orange.opacity(0.2)
        case .careful: Color.primary.opacity(0.8)
        }
    }
}

/// A size in monospaced figures, so columns of sizes line up.
struct SizeLabel: View {
    let bytes: Int64
    var weight: Font.Weight = .semibold

    var body: some View {
        Text(ByteFormat.string(bytes))
            .font(.system(.callout, design: .monospaced).weight(weight))
    }
}

/// The big number at the top of a screen.
struct HeroFigure: View {
    let caption: String
    let bytes: Int64
    let footnote: String
    var size: CGFloat = 56

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(caption)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(ByteFormat.string(bytes))
                .font(.system(size: size, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.default, value: bytes)
            Text(footnote)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One horizontal bar for the whole disk, split into what each part of it is doing.
struct DiskBar: View {
    struct Segment: Identifiable {
        let id: String
        var label: String
        var bytes: Int64
        var color: Color
        /// Drawn as an outlined swatch in the legend: the empty remainder of the bar.
        var isRemainder = false
    }

    var segments: [Segment]
    var total: Int64
    var height: CGFloat = 26

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geometry in
                HStack(spacing: 1) {
                    ForEach(segments.filter { !$0.isRemainder }) { segment in
                        Rectangle()
                            .fill(segment.color)
                            .frame(width: max(0, geometry.size.width * CGFloat(segment.bytes) / CGFloat(max(total, 1))))
                    }
                    Spacer(minLength: 0)
                }
                .animation(.snappy, value: segments.map(\.bytes))
            }
            .frame(height: height)
            .background(.quaternary)
            .clipShape(.rect(cornerRadius: height * 0.28))
            .accessibilityHidden(true)

            HStack(spacing: 20) {
                ForEach(segments) { segment in
                    HStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(segment.isRemainder ? AnyShapeStyle(.quaternary) : AnyShapeStyle(segment.color))
                            .frame(width: 10, height: 10)
                        Text(segment.label)
                            .foregroundStyle(.secondary)
                        Text(ByteFormat.string(segment.bytes))
                            .font(.system(.caption, design: .monospaced))
                    }
                    .font(.caption)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

extension DiskBar {
    static let keepColor = Color.secondary.opacity(0.55)
    static let foundColor = Color.accentColor.opacity(0.35)
    static let selectedColor = Color.accentColor
}

/// The floating bar at the bottom of a screen: what is selected on the left, the action on the right.
struct ActionBar<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let trailing: Trailing

    init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 16) {
            leading
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.leading, 18)
        .padding(.trailing, 12)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}

/// Two lines of text for the left side of an `ActionBar`.
struct ActionSummary: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .fontWeight(.semibold)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

/// A rounded, hairline-bordered container for a group of rows.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary.opacity(0.5), in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.separator)
        }
    }
}

/// Shown when Downloads or the Trash could not be read.
struct FullDiskAccessNote: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let folders = model.unreadableFolders.joined(separator: " and ")
        Card {
            HStack(spacing: 12) {
                Image(systemName: "lock")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(folders.prefix(1).uppercased() + folders.dropFirst()) could not be scanned")
                        .fontWeight(.semibold)
                    Text("macOS keeps \(model.unreadableFolders.count == 1 ? "it" : "them") private. Everything else was scanned. Grant Full Disk Access in Privacy & Security, then scan again.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Button("Open Privacy Settings") {
                    model.openFullDiskAccessSettings()
                }
            }
            .padding(14)
        }
    }
}

extension View {
    /// The shared page layout: padded, left-aligned, and not stretched across a very wide window.
    func pageLayout(maxWidth: CGFloat = 980) -> some View {
        self
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
    }
}
