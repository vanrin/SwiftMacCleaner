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

/// A short label next to a title: what a row waits for, whether it needs a password, or that it is new.
struct Badge: View {
    enum Style {
        case waits, password, new, neutral
    }

    let text: String
    var style: Style = .neutral

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(foreground)
            .background(background, in: .rect(cornerRadius: 5))
    }

    private var foreground: Color {
        switch style {
        case .waits: Color.orange.mix(with: .primary, by: 0.45)
        case .password: Color(nsColor: .windowBackgroundColor)
        case .new: Color.accentColor.mix(with: .primary, by: 0.25)
        case .neutral: Color.primary.opacity(0.75)
        }
    }

    private var background: Color {
        switch style {
        case .waits: Color.orange.opacity(0.2)
        case .password: Color.primary.opacity(0.8)
        case .new: Color.accentColor.opacity(0.15)
        case .neutral: Color.primary.opacity(0.08)
        }
    }
}

/// A size in monospaced figures, so columns of sizes line up.
struct SizeLabel: View {
    let bytes: Int64
    var weight: Font.Weight = .semibold
    /// macOS could not say how big this is, so the row says so instead of showing a number.
    var unknown: Bool = false

    var body: some View {
        if unknown {
            Text("size unknown")
                .font(.callout)
                .foregroundStyle(.secondary)
        } else {
            Text(ByteFormat.string(bytes))
                .font(.system(.callout, design: .monospaced).weight(weight))
        }
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
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Thin diagonal lines, for a bar segment that is not quite used and not quite free.
private struct Hatch: View {
    var color: Color

    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 6
            var x: CGFloat = -size.height
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                context.stroke(path, with: .color(color), lineWidth: 1.5)
                x += step
            }
        }
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
        /// Drawn as diagonal stripes: space macOS may take back on its own.
        var pattern = false
    }

    var segments: [Segment]
    var total: Int64
    var height: CGFloat = 26

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geometry in
                HStack(spacing: 1) {
                    ForEach(segments.filter { !$0.isRemainder }) { segment in
                        fill(for: segment)
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
                        swatch(for: segment)
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

    @ViewBuilder
    private func fill(for segment: Segment) -> some View {
        if segment.pattern {
            Rectangle()
                .fill(.quaternary)
                .overlay(Hatch(color: segment.color))
        } else {
            Rectangle()
                .fill(segment.color)
        }
    }

    @ViewBuilder
    private func swatch(for segment: Segment) -> some View {
        if segment.isRemainder {
            RoundedRectangle(cornerRadius: 3)
                .fill(.quaternary)
        } else if segment.pattern {
            RoundedRectangle(cornerRadius: 3)
                .fill(.quaternary)
                .overlay(Hatch(color: segment.color).clipShape(RoundedRectangle(cornerRadius: 3)))
        } else {
            RoundedRectangle(cornerRadius: 3)
                .fill(segment.color)
        }
    }
}

extension DiskBar {
    static let keepColor = Color.secondary.opacity(0.55)
    static let foundColor = Color.accentColor.opacity(0.35)
    static let selectedColor = Color.accentColor
    static let purgeableColor = Color.secondary.opacity(0.7)
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
    var accent = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent ? Color.accentColor.opacity(0.06) : Color.clear, in: .rect(cornerRadius: 12))
        .background(.background.secondary.opacity(0.5), in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(accent ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator))
        }
    }
}

/// What the scan found and deliberately left alone, with the rule that kept each item.
struct ProtectedList: View {
    var title = "Protected on purpose"
    var subtitle = "Found, but left alone because a rule says so. Nothing here can be ticked."
    let items: [ProtectedItem]

    var body: some View {
        Card {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield")
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 12)
                SizeLabel(bytes: items.reduce(0) { $0 + ($1.size ?? 0) })
            }
            .padding(16)

            ForEach(items) { item in
                Divider()
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(item.why)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 12)
                    Badge(text: item.rule.rawValue, style: .neutral)
                    if let size = item.size {
                        SizeLabel(bytes: size, weight: .regular)
                            .foregroundStyle(.secondary)
                            .frame(width: 76, alignment: .trailing)
                    } else {
                        Text("kept")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 76, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
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

/// The last clean left things in the Trash that can still go back where they were.
struct PutBackCard: View {
    @Environment(AppModel.self) private var model
    let manifest: PutBack.Manifest

    var body: some View {
        let count = manifest.items.count
        let size = manifest.items.reduce(Int64(0)) { $0 + $1.size }
        Card(accent: true) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(ByteFormat.string(size)) is in the Trash and can still be put back")
                        .fontWeight(.semibold)
                    Text("\(count == 1 ? "1 item" : "\(count) items") from your clean on \(manifest.date.formatted(date: .abbreviated, time: .shortened)). Put Back returns every one of them to where it was. Emptying the Trash frees the space for good. Either way, this offer disappears once the Trash is emptied.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Button("Put Back \(count == 1 ? "1 Item" : "\(count) Items")") { model.putBack() }
                Button("Show Trash") { model.openTrash() }
            }
            .padding(14)
        }
    }
}

/// A one-line confirmation after Put Back.
struct PutBackMessage: View {
    let text: String

    var body: some View {
        Card {
            HStack(spacing: 12) {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
                Text(text)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
        }
    }
}

/// The badges a finding earns: what it waits for, and whether it needs a password.
struct FindingBadges: View {
    let finding: Finding
    let active: InUseCheck?

    var body: some View {
        if let active {
            Badge(text: active.badge, style: .waits)
        }
        if finding.method == .adminCommand {
            Badge(text: "Asks for your password", style: .password)
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
