//
//  CleanUpColumn.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The column beside the manager's list: each area the clean-up looked at, with how much was found in it.
struct CleanUpColumn: View {
    @Environment(AppModel.self) private var model
    @Environment(CleanUpModel.self) private var cleanUp

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
            ForEach(model.areas(in: cleanUp.group)) { area in
                ManagerColumnRow(title: area.title, value: value(for: area), isSelected: cleanUp.openArea == area,
                                 isProminent: true) {
                    cleanUp.open(area)
                }
            }
        }
    }

    /// What stands at the end of an area's row: how much was found, or why there is nothing.
    private func value(for area: Area) -> String {
        let found = cleanUp.foundSize(in: area)
        if found > 0 { return ByteFormat.string(found) }
        return switch cleanUp.areaState(for: area) {
        case .skipped: "Skipped"
        case .idle: "Not scanned"
        case .queued, .scanning, .finished: "Clean"
        }
    }
}
