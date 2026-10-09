//
//  LoginItemsPane.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The apps that open at login, as System Events lists them, each with a tick box.
struct LoginItemsPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let performance = model.performance
        VStack(alignment: .leading, spacing: Design.Spacing.large) {
            PaneHeading(title: PerformanceModel.Section.loginItems.title, detail: PerformanceModel.Section.loginItems.detail) {
                Spacer(minLength: 0)
                Menu("Select") {
                    Button("All", action: performance.selectAll)
                    Button("None", action: performance.selectNone)
                }
                .fixedSize()
                .disabled(performance.loginItems.isEmpty)
            }
            if let failure = performance.loginItemsFailure {
                Notice(symbol: "exclamationmark.triangle.fill", isWarning: true, title: "Login items could not be read", text: failure) {
                    Button("Open Privacy Settings", action: openAutomationSettings)
                        .buttonStyle(.pill)
                }
            } else if performance.loginItems.isEmpty {
                ContentUnavailableView {
                    Label("No login items", systemImage: "power")
                } description: {
                    Text("Nothing opens by itself when you log in.")
                }
            } else {
                ScrollView {
                    GlassPanel {
                        LazyVStack(spacing: 0) {
                            ForEach(performance.loginItems) { item in
                                LoginItemRow(item: item, showsDivider: item.id != performance.loginItems.first?.id)
                            }
                        }
                    }
                }
            }
        }
    }

    private func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}
