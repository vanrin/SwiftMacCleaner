//
//  SpaceView.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// Largest Folders: measures a whole folder tree and lets the user walk down into the biggest parts.
/// It only reads. Removing things stays with the clean-up scan, which knows what is safe.
struct SpaceView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let space = model.space
        Group {
            switch space.phase {
            case .idle:
                SpaceIntro()
            case .measuring:
                SpaceMeasuring()
            case .done:
                if let node = space.current {
                    SpaceBrowser(node: node)
                }
            }
        }
        .navigationTitle("Largest Folders")
        .navigationSubtitle(subtitle(space))
        .toolbar {
            if space.phase == .measuring {
                ToolbarItem(placement: .primaryAction) {
                    Button("Stop", systemImage: "stop.fill") { space.stop() }
                        .help("Stop measuring")
                }
            }
            if space.phase == .done {
                ToolbarItem(placement: .primaryAction) {
                    Button("Start Over", systemImage: "arrow.counterclockwise") { space.reset() }
                        .help("Choose what to measure again")
                }
            }
        }
    }

    private func subtitle(_ space: SpaceModel) -> String {
        switch space.phase {
        case .idle: "\(model.disk.name), \(ByteFormat.string(model.disk.used)) in use"
        case .measuring: "Measuring \(space.rootTitle)"
        case .done: "\(space.rootTitle), measured in \(Int(space.duration.rounded())) s"
        }
    }
}

private struct SpaceIntro: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var space = model.space
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("See where the space went")
                        .font(.largeTitle.bold())
                    Text("Measures every folder and lists the biggest ones, so you can find what the clean-up scan does not know about. It only reads. Nothing is removed from this screen.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Picker("What to measure", selection: $space.scope) {
                        ForEach(SpaceModel.Scope.allCases) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    Text(space.scope == .home
                         ? "Your own files: projects, Library, Documents, Downloads and the rest of \(space.displayPath(space.home.path))."
                         : "Everything on \(model.disk.name): your home folder plus Applications, the system Library and other users.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if !model.hasFullDiskAccess {
                    Card {
                        HStack(spacing: 12) {
                            Image(systemName: "lock")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Full Disk Access is off")
                                    .fontWeight(.semibold)
                                Text("macOS will ask about Documents, Desktop and Downloads one by one, and folders it keeps private will show as unreadable. Granting access first gives a complete picture.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 12)
                            Button("Open Privacy Settings") { model.openFullDiskAccessSettings() }
                        }
                        .padding(14)
                    }
                }
            }
            .pageLayout(maxWidth: 760)
        }
        .safeAreaInset(edge: .bottom) {
            ActionBar {
                ActionSummary(
                    title: "\(ByteFormat.string(model.disk.used)) in use on \(model.disk.name)",
                    detail: "Measuring a full disk can take a few minutes. You can stop at any time."
                )
            } trailing: {
                Button("Measure \(space.scope.title)") { space.start() }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
            }
        }
    }
}

private struct SpaceMeasuring: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let space = model.space
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HeroFigure(
                    caption: "Measured so far",
                    bytes: space.progress.measured,
                    footnote: "\(space.progress.items.formatted()) files and folders"
                )
                ProgressView()
                    .progressViewStyle(.linear)
                Text(space.displayPath(space.progress.path))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .pageLayout(maxWidth: 760)
        }
    }
}

private struct SpaceBrowser: View {
    @Environment(AppModel.self) private var model
    let node: SpaceNode

    var body: some View {
        let space = model.space
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if space.trail.count > 1 { trail(space) }
                header(space)
                VStack(spacing: 0) {
                    ForEach(node.children) { child in
                        Divider()
                        SpaceRow(node: child, parentSize: node.size)
                    }
                    if node.smallerItemsSize > 0 {
                        Divider()
                        smallerItems
                    }
                }
            }
            .pageLayout()
        }
    }

    /// The path from the measured root to this folder. Each step goes back up to it.
    private func trail(_ space: SpaceModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(space.trail.indices), id: \.self) { index in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    let isCurrent = index == space.trail.count - 1
                    Button(space.title(at: index)) { space.goBack(to: index) }
                        .buttonStyle(.borderless)
                        .fontWeight(isCurrent ? .semibold : .regular)
                        .foregroundStyle(isCurrent ? .primary : .secondary)
                        .disabled(isCurrent)
                }
            }
        }
    }

    private func header(_ space: SpaceModel) -> some View {
        let share = SpaceRow.share(of: node.size, in: model.disk.used)
        var footnote = "\(share) of the \(ByteFormat.string(model.disk.used)) in use on \(model.disk.name)"
        if node.isIncomplete { footnote += ". Some folders could not be read, so the real figure is higher" }
        return HStack(alignment: .bottom) {
            HeroFigure(caption: space.displayPath(node.path), bytes: node.size, footnote: footnote, size: 44)
            Spacer(minLength: 12)
            Button("Show in Finder") { model.showInFinder(URL(fileURLWithPath: node.path)) }
        }
    }

    private var smallerItems: some View {
        HStack(spacing: 12) {
            Image(systemName: "ellipsis")
                .frame(width: 22)
                .foregroundStyle(.secondary)
            Text(node.children.isEmpty ? "Files and folders, none over 20 MB" : "Everything smaller than 20 MB")
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            SpaceRow.shareBar(node.smallerItemsSize, of: node.size, tint: AnyShapeStyle(.secondary))
            Text(SpaceRow.share(of: node.smallerItemsSize, in: node.size))
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
            SizeLabel(bytes: node.smallerItemsSize, weight: .regular)
                .frame(width: 84, alignment: .trailing)
            // Stands in for the chevron and Finder button, so the columns line up with the rows above.
            Color.clear.frame(width: 50, height: 1)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 4)
    }
}

private struct SpaceRow: View {
    @Environment(AppModel.self) private var model
    let node: SpaceNode
    let parentSize: Int64

    private var canOpen: Bool { node.isDirectory && !node.isUnreadable }
    private var friendlyName: String? {
        node.isDirectory ? SpaceScanner.friendlyName(forFolderAt: node.path) : nil
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                model.space.open(node)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: node.isUnreadable ? "lock" : node.isDirectory ? "folder" : "doc")
                        .frame(width: 22)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(node.name)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if node.isUnreadable {
                            Text("macOS would not let the app look inside")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        } else if let friendlyName {
                            Text(friendlyName)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else if node.isIncomplete {
                            Text("Part of it could not be read, so this is a lower bound")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 12)
                    if node.isUnreadable {
                        Text("Unknown")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        Self.shareBar(node.size, of: parentSize, tint: AnyShapeStyle(.tint))
                        Text(Self.share(of: node.size, in: parentSize))
                            .font(.callout)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)
                        SizeLabel(bytes: node.size)
                            .frame(width: 84, alignment: .trailing)
                    }
                    Image(systemName: "chevron.right")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .frame(width: 14)
                        .opacity(canOpen ? 1 : 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .allowsHitTesting(canOpen)
            .accessibilityHint(canOpen ? "Shows what is inside" : "")

            Button {
                model.showInFinder(URL(fileURLWithPath: node.path))
            } label: {
                Image(systemName: "magnifyingglass")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("Show in Finder")
            .accessibilityLabel("Show \(node.name) in Finder")
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 4)
    }

    /// "42%", or "<1%" for anything that would round to nothing.
    static func share(of size: Int64, in total: Int64) -> String {
        guard total > 0, size > 0 else { return "0%" }
        let percent = Double(size) / Double(total) * 100
        return percent < 1 ? "<1%" : "\(Int(percent.rounded()))%"
    }

    static func shareBar(_ size: Int64, of total: Int64, tint: AnyShapeStyle) -> some View {
        let width: CGFloat = 140
        let fraction = total > 0 ? CGFloat(size) / CGFloat(total) : 0
        return Capsule()
            .fill(.quaternary)
            .frame(width: width, height: 5)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(tint)
                    .frame(width: max(3, width * min(1, fraction)))
            }
            .accessibilityHidden(true)
    }
}
