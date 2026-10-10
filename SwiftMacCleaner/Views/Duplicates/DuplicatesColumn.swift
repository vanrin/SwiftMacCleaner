//
//  DuplicatesColumn.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The column beside the list of duplicates: every group, and under it one row per kind of file found.
struct DuplicatesColumn: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let duplicates = model.duplicates
        ScrollView {
            VStack(alignment: .leading, spacing: Design.Spacing.tight / 2) {
                ManagerColumnRow(title: "All Duplicates", value: value(for: nil, in: duplicates), isSelected: duplicates.kind == nil,
                                 isProminent: true) {
                    duplicates.kind = nil
                }
                if !duplicates.kinds.isEmpty {
                    Divider()
                        .padding(.vertical, Design.Spacing.small)
                    ForEach(duplicates.kinds) { kind in
                        ManagerColumnRow(title: kind.title, value: value(for: kind, in: duplicates), isSelected: duplicates.kind == kind) {
                            duplicates.kind = kind
                        }
                    }
                }
            }
        }
        .scrollIndicators(.never)
    }

    /// What stands at the end of a row: what keeping one copy of each of its groups gives back. That is
    /// nothing for copies that share their space, and the row says so rather than switch to a count.
    private func value(for kind: DuplicateKind?, in duplicates: DuplicatesModel) -> String {
        ByteFormat.string(duplicates.groups(of: kind).reduce(0) { $0 + $1.reclaimable })
    }
}
