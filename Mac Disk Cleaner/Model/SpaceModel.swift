//
//  SpaceModel.swift
//  Mac Disk Cleaner
//

import Foundation
import Observation

/// State behind the Largest Folders screen: one measurement, and where in it the user is looking.
@Observable
final class SpaceModel {
    enum Scope: String, CaseIterable, Identifiable {
        case home, disk

        var id: String { rawValue }
        var title: String {
            switch self {
            case .home: "Home Folder"
            case .disk: "Whole Disk"
            }
        }
    }

    enum Phase {
        case idle, measuring, done
    }

    /// Where the data volume is mounted. Everything a user can remove lives under it.
    static let dataVolume = URL(fileURLWithPath: "/System/Volumes/Data", isDirectory: true)

    let home: URL
    var scope: Scope = .home

    private(set) var phase: Phase = .idle
    private(set) var progress = SpaceProgress()
    private(set) var duration: TimeInterval = 0
    /// What the measured root is called, such as "Home Folder".
    private(set) var rootTitle = ""
    /// The folders from the measured root down to the one on screen.
    private(set) var trail: [SpaceNode] = []

    @ObservationIgnored private var task: Task<Void, Never>?

    init(home: URL) {
        self.home = home
    }

    var current: SpaceNode? { trail.last }
    var root: SpaceNode? { trail.first }

    func start() {
        switch scope {
        case .home: start(root: home, title: Scope.home.title)
        case .disk: start(root: Self.dataVolume, title: DiskInfo.current(for: home).name)
        }
    }

    func start(root: URL, title: String) {
        task?.cancel()
        trail = []
        rootTitle = title
        progress = SpaceProgress()
        phase = .measuring
        let started = Date()
        task = Task {
            let node = await SpaceScanner.scan(root: root) { progress in
                Task { @MainActor in
                    if self.phase == .measuring { self.progress = progress }
                }
            }
            guard !Task.isCancelled else { return }
            duration = Date().timeIntervalSince(started)
            trail = node.map { [$0] } ?? []
            phase = node == nil ? .idle : .done
        }
    }

    func stop() {
        task?.cancel()
        phase = trail.isEmpty ? .idle : .done
    }

    /// Forgets the measurement and goes back to choosing what to measure.
    func reset() {
        task?.cancel()
        trail = []
        phase = .idle
    }

    /// Steps into a folder that was listed inside the current one.
    func open(_ node: SpaceNode) {
        guard phase == .done, node.isDirectory, !node.isUnreadable else { return }
        trail.append(node)
    }

    /// Steps back up to the folder at `index` in the trail.
    func goBack(to index: Int) {
        guard trail.indices.contains(index) else { return }
        trail.removeSubrange((index + 1)...)
    }

    /// The name shown for a folder in the trail: the root gets its title, the rest their own names.
    func title(at index: Int) -> String {
        index == 0 ? rootTitle : trail[index].name
    }

    /// The path as the user knows it: `~` for home, and without the data volume's mount point.
    func displayPath(_ path: String) -> String {
        let homePath = home.path
        if path == homePath || path.hasPrefix(homePath + "/") { return "~" + path.dropFirst(homePath.count) }
        let volume = Self.dataVolume.path
        if path == volume { return "/" }
        if path.hasPrefix(volume + "/") { return String(path.dropFirst(volume.count)) }
        return path
    }
}
